import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';

/// UCD040 – Link Client Account
///
/// Shared service for the linking-code flow:
/// • **Caregiver side** – generate / list / revoke share codes.
/// • **Therapist side** – verify a code, preview the child, confirm link.
class ClientLinkingService {
  final SupabaseClient _client = SupabaseService.client;

  // ═══════════════════════════════════════════════════════════════════════
  // ── Caregiver: Generate & manage share codes ──────────────────────────
  // ═══════════════════════════════════════════════════════════════════════

  /// Generates a new 6-character share code (XXX-XXX) for [childProfileId].
  /// Previous active codes for the same child are expired automatically.
  Future<LinkingCode> generateShareCode(String childProfileId) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    // Expire any existing active codes for this child
    await _client
        .from('linking_codes')
        .update({'status': 'expired'})
        .eq('caregiver_id', userId)
        .eq('child_profile_id', childProfileId)
        .eq('status', 'active');

    // Generate unique code
    String code = _generateCode();

    // Insert (retry on duplicate)
    Map<String, dynamic>? row;
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        final result = await _client
            .from('linking_codes')
            .insert({
              'code': code,
              'caregiver_id': userId,
              'child_profile_id': childProfileId,
              'status': 'active',
            })
            .select()
            .single();
        row = result;
        break;
      } catch (e) {
        // Likely duplicate code – regenerate
        code = _generateCode();
      }
    }

    if (row == null) throw Exception('Failed to generate a unique code');

    return LinkingCode.fromJson(row);
  }

  /// Returns all codes created by the current caregiver.
  Future<List<LinkingCode>> getMyCodes() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return [];

    // Also expire old ones on fetch
    try {
      await _client.rpc('expire_old_linking_codes');
    } catch (_) {}

    final rows = await _client
        .from('linking_codes')
        .select()
        .eq('caregiver_id', userId)
        .order('created_at', ascending: false) as List;

    return rows.map((r) => LinkingCode.fromJson(r)).toList();
  }

  /// Manually revoke (expire) a code.
  Future<void> revokeCode(String codeId) async {
    await _client
        .from('linking_codes')
        .update({'status': 'expired'}).eq('id', codeId);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── Therapist: Verify & confirm linking ───────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════

  /// Validates a code but does NOT consume it yet.
  /// Returns a preview of the child (name + avatar) or an error.
  Future<LinkVerifyResult> verifyCode(String code) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      return LinkVerifyResult.error('Not authenticated');
    }

    final normalized = code.trim().toUpperCase();

    // 1. Look up the code
    final row = await _client
        .from('linking_codes')
        .select()
        .eq('code', normalized)
        .eq('status', 'active')
        .maybeSingle();

    if (row == null) {
      return LinkVerifyResult.error(
          'Invalid or expired code. Please ask the Caregiver for a new one.');
    }

    // Check expiry
    final expiresAt = DateTime.parse(row['expires_at'] as String);
    if (expiresAt.isBefore(DateTime.now().toUtc())) {
      // Mark expired
      await _client
          .from('linking_codes')
          .update({'status': 'expired'}).eq('id', row['id']);
      return LinkVerifyResult.error(
          'Invalid or expired code. Please ask the Caregiver for a new one.');
    }

    final childProfileId = row['child_profile_id'] as String;
    final caregiverId = row['caregiver_id'] as String;

    // 2. Check already linked
    final existingLink = await _client
        .from('therapist_client_link')
        .select('id')
        .eq('therapist_id', userId)
        .eq('client_id', caregiverId)
        .maybeSingle();

    if (existingLink != null) {
      return LinkVerifyResult.error(
          'This client is already linked to your account.');
    }

    // 3. Fetch child preview
    final child = await _client
        .from('child_profiles')
        .select('id, full_name, age, avatar_url')
        .eq('id', childProfileId)
        .maybeSingle();

    if (child == null) {
      return LinkVerifyResult.error('Child profile not found.');
    }

    return LinkVerifyResult.success(
      codeId: row['id'] as String,
      childProfileId: childProfileId,
      caregiverId: caregiverId,
      childName: (child['full_name'] as String?) ?? 'Child',
      childAge: child['age'] as int?,
      childAvatarUrl: child['avatar_url'] as String?,
    );
  }

  /// Consumes the code and creates the therapist↔caregiver link.
  /// Call only after a successful [verifyCode] + user confirmation.
  Future<void> confirmLink(LinkVerifyResult preview) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    // 1. Create therapist_client_link
    await _client.from('therapist_client_link').insert({
      'therapist_id': userId,
      'client_id': preview.caregiverId,
    });

    // 2. Mark code as used
    await _client.from('linking_codes').update({
      'status': 'used',
      'used_by': userId,
      'used_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', preview.codeId!);

    // 3. Notify caregiver
    try {
      await _client.from('notifications').insert({
        'user_id': preview.caregiverId,
        'title': '🔗 Therapist Linked',
        'body':
            'A therapist has been linked to ${preview.childName}\'s account.',
        'type': 'client_linked',
        'is_read': false,
      });
    } catch (_) {
      // Best-effort
    }

    debugPrint('ClientLinkingService: link confirmed for ${preview.childName}');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── UCD041: Unlink Client Account ─────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════

  /// Removes the therapist↔caregiver link, logs the event, and notifies
  /// the caregiver. The therapist permanently loses access to the child's
  /// profile and therapy history.
  Future<void> unlinkClient({
    required String caregiverId,
    required String childName,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    // 1. Fetch therapist display name for the notification
    String therapistName = 'Your therapist';
    try {
      final profile = await _client
          .from('profiles')
          .select('full_name')
          .eq('user_id', userId)
          .maybeSingle();
      if (profile != null && profile['full_name'] != null) {
        therapistName = profile['full_name'] as String;
      }
    } catch (_) {}

    // 2. Delete the relationship record
    await _client
        .from('therapist_client_link')
        .delete()
        .eq('therapist_id', userId)
        .eq('client_id', caregiverId);

    // 3. Log the dissociation event for audit
    try {
      await _client.from('audit_log').insert({
        'user_id': userId,
        'action': 'client_unlinked',
        'details':
            'Therapist $therapistName unlinked from caregiver $caregiverId '
                '(child: $childName)',
      });
    } catch (_) {
      // Best-effort – audit table may not exist yet
    }

    // 4. Notify the caregiver
    try {
      await _client.from('notifications').insert({
        'user_id': caregiverId,
        'title': '🔗 Therapist Disconnected',
        'body': '$therapistName has disconnected from your profile.',
        'type': 'client_unlinked',
        'is_read': false,
      });
    } catch (_) {
      // Best-effort
    }

    debugPrint(
        'ClientLinkingService: unlinked from caregiver $caregiverId ($childName)');
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  /// Generates a random XXX-XXX code using unambiguous characters.
  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    String part(int len) =>
        List.generate(len, (_) => chars[rng.nextInt(chars.length)]).join();
    return '${part(3)}-${part(3)}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Data classes ─────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

@immutable
class LinkingCode {
  final String id;
  final String code;
  final String caregiverId;
  final String childProfileId;
  final String status; // active | used | expired
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? usedBy;
  final DateTime? usedAt;

  const LinkingCode({
    required this.id,
    required this.code,
    required this.caregiverId,
    required this.childProfileId,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.usedBy,
    this.usedAt,
  });

  bool get isActive => status == 'active';
  bool get isExpired =>
      status == 'expired' || expiresAt.isBefore(DateTime.now().toUtc());

  factory LinkingCode.fromJson(Map<String, dynamic> json) {
    return LinkingCode(
      id: json['id'] as String,
      code: json['code'] as String,
      caregiverId: json['caregiver_id'] as String,
      childProfileId: json['child_profile_id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      usedBy: json['used_by'] as String?,
      usedAt: json['used_at'] != null
          ? DateTime.parse(json['used_at'] as String)
          : null,
    );
  }
}

/// Result of verifying a linking code.
@immutable
class LinkVerifyResult {
  final bool isValid;
  final String? errorMessage;

  // Preview fields (only set when isValid == true)
  final String? codeId;
  final String? childProfileId;
  final String? caregiverId;
  final String? childName;
  final int? childAge;
  final String? childAvatarUrl;

  const LinkVerifyResult._({
    required this.isValid,
    this.errorMessage,
    this.codeId,
    this.childProfileId,
    this.caregiverId,
    this.childName,
    this.childAge,
    this.childAvatarUrl,
  });

  factory LinkVerifyResult.success({
    required String codeId,
    required String childProfileId,
    required String caregiverId,
    required String childName,
    int? childAge,
    String? childAvatarUrl,
  }) {
    return LinkVerifyResult._(
      isValid: true,
      codeId: codeId,
      childProfileId: childProfileId,
      caregiverId: caregiverId,
      childName: childName,
      childAge: childAge,
      childAvatarUrl: childAvatarUrl,
    );
  }

  factory LinkVerifyResult.error(String message) {
    return LinkVerifyResult._(isValid: false, errorMessage: message);
  }
}
