import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';

/// Linking-code flow between caregiver and therapist.
/// Actual DB table: `linking_code` (code_id, child_id, code, is_active, expires_at, used_at, used_by)
/// Actual link table: `therapist_client_link` (link_id, therapist_id, child_id)
class ClientLinkingService {
  final SupabaseClient _client = SupabaseService.client;

  // ── Caregiver: generate a share code ─────────────────────────────────

  /// Returns the unique, stable share code for [childId].
  /// Each profile gets one permanent code. If one already exists and is active,
  /// it is returned. Otherwise a new deterministic code is generated from the
  /// user ID and stored.
  Future<String> generateShareCode(String childId) async {
    // 1. Check for an existing active code for this child
    try {
      final existing = await _client
          .from('linking_code')
          .select('code')
          .eq('child_id', childId)
          .eq('is_active', true)
          .maybeSingle();
      if (existing != null) {
        return existing['code'] as String;
      }
    } catch (_) {}

    // 2. Generate a deterministic code from the user ID so it's always the same
    final code = _deterministicCode(childId);

    // 3. Try to insert it (or return existing if race condition)
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final result = await _client
            .from('linking_code')
            .insert({
              'child_id': childId,
              'code': code,
              'is_active': true,
              'expires_at': DateTime.now()
                  .add(const Duration(days: 365))
                  .toUtc()
                  .toIso8601String(),
            })
            .select('code')
            .single();
        return result['code'] as String;
      } catch (_) {
        // Code might already exist (race condition) — try fetching again
        try {
          final existing = await _client
              .from('linking_code')
              .select('code')
              .eq('child_id', childId)
              .eq('is_active', true)
              .maybeSingle();
          if (existing != null) return existing['code'] as String;
        } catch (_) {}
      }
    }
    throw Exception('Failed to generate linking code');
  }

  /// Derives a stable XXX-XXX code from [userId] using its hash.
  String _deterministicCode(String userId) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    // Use a simple hash of the userId to produce 6 stable characters
    var hash = userId.hashCode.abs();
    // Add more entropy from the string itself
    for (var i = 0; i < userId.length; i++) {
      hash = (hash * 31 + userId.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    final digits = <String>[];
    var h = hash;
    for (var i = 0; i < 6; i++) {
      digits.add(chars[h % chars.length]);
      h = (h ~/ chars.length) + (h * 7 + 13) & 0x7FFFFFFF;
    }
    return '${digits.sublist(0, 3).join()}-${digits.sublist(3, 6).join()}';
  }

  // ── Therapist: verify & confirm ───────────────────────────────────────

  /// Validates [code] and returns a preview without consuming it.
  Future<LinkVerifyResult> verifyCode(String code) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return LinkVerifyResult.error('Not authenticated');

    final normalized = code.trim().toUpperCase();

    // 1. Find the active code
    final row = await _client
        .from('linking_code')
        .select()
        .eq('code', normalized)
        .eq('is_active', true)
        .maybeSingle();

    if (row == null) {
      return LinkVerifyResult.error(
          'Invalid or expired code. Please ask the caregiver for a new one.');
    }

    // Check expiry
    final expiresAtStr = row['expires_at'] as String?;
    if (expiresAtStr != null) {
      final expiresAt = DateTime.parse(expiresAtStr);
      if (expiresAt.isBefore(DateTime.now().toUtc())) {
        try {
          await _client
              .from('linking_code')
              .update({'is_active': false}).eq('code_id', row['code_id']);
        } catch (_) {}
        return LinkVerifyResult.error(
            'Code has expired. Please ask the caregiver for a new one.');
      }
    }

    final childId = row['child_id'] as String;

    // 2 & 3. In parallel: check already linked + fetch child profile
    final results = await Future.wait([
      _client
          .from('therapist_client_link')
          .select('link_id')
          .eq('therapist_id', userId)
          .eq('child_id', childId)
          .maybeSingle()
          .catchError((_) => null),
      _client
          .from('profiles')
          .select('full_name, date_of_birth, avatar_url')
          .eq('user_id', childId)
          .maybeSingle()
          .catchError((_) => null),
    ]);

    if (results[0] != null) {
      return LinkVerifyResult.error(
          'This child is already linked to your account.');
    }

    final child = results[1] as Map<String, dynamic>?;
    if (child == null) {
      return LinkVerifyResult.error('Child profile not found.');
    }

    int? age;
    final dob = child['date_of_birth'] as String?;
    if (dob != null) {
      final dobDate = DateTime.tryParse(dob);
      if (dobDate != null) {
        final now = DateTime.now();
        age = now.year -
            dobDate.year -
            ((now.month < dobDate.month ||
                    (now.month == dobDate.month && now.day < dobDate.day))
                ? 1
                : 0);
      }
    }

    return LinkVerifyResult.success(
      codeId: row['code_id'] as String,
      childId: childId,
      childName: (child['full_name'] as String?) ?? 'Child',
      childAge: age,
      childAvatarUrl: child['avatar_url'] as String?,
    );
  }

  /// Consumes the code and creates the therapist↔child link.
  Future<void> confirmLink(LinkVerifyResult preview) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    await Future.wait([
      _client.from('therapist_client_link').insert({
        'therapist_id': userId,
        'child_id': preview.childId,
      }),
      _client.from('linking_code').update({
        'is_active': false,
        'used_by': userId,
        'used_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('code_id', preview.codeId!),
    ]);

    debugPrint(
        'ClientLinkingService: linked therapist to child ${preview.childName}');
  }

  // ── Therapist: unlink a client ────────────────────────────────────────

  /// Removes the therapist↔child link from `therapist_client_link`.
  /// Uses the currently authenticated therapist's ID and the child's [childId].
  Future<void> unlinkClient({
    required String caregiverId,
    required String childName,
    required String childId,
  }) async {
    final therapistId = SupabaseService.currentUserId;
    if (therapistId == null) throw Exception('Not authenticated');

    await _client
        .from('therapist_client_link')
        .delete()
        .eq('therapist_id', therapistId)
        .eq('child_id', childId);

    debugPrint(
        'ClientLinkingService: unlinked therapist from child $childName');
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    String part(int len) =>
        List.generate(len, (_) => chars[rng.nextInt(chars.length)]).join();
    return '${part(3)}-${part(3)}';
  }
}

// ── Data classes ──────────────────────────────────────────────────────────

@immutable
class LinkVerifyResult {
  final bool isValid;
  final String? errorMessage;

  final String? codeId;
  final String? childId;
  final String? childName;
  final int? childAge;
  final String? childAvatarUrl;

  const LinkVerifyResult._({
    required this.isValid,
    this.errorMessage,
    this.codeId,
    this.childId,
    this.childName,
    this.childAge,
    this.childAvatarUrl,
  });

  factory LinkVerifyResult.success({
    required String codeId,
    required String childId,
    required String childName,
    int? childAge,
    String? childAvatarUrl,
  }) {
    return LinkVerifyResult._(
      isValid: true,
      codeId: codeId,
      childId: childId,
      childName: childName,
      childAge: childAge,
      childAvatarUrl: childAvatarUrl,
    );
  }

  factory LinkVerifyResult.error(String message) {
    return LinkVerifyResult._(isValid: false, errorMessage: message);
  }
}
