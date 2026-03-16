import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../models/flagged_message.dart';

/// UCD035 – Moderate Communication
///
/// Admin-only service that powers the moderation queue:
/// - Fetch flagged/reported messages (pending & resolved)
/// - Dismiss a false alarm
/// - Delete an offending message (hides content from chat)
/// - Suspend the sender (sets profiles.is_active = false)
/// - Write audit-log entries for every moderation action
class ModerationService {
  final SupabaseClient _client = SupabaseService.client;

  // ── Fetch flagged messages ────────────────────────────────────────────

  /// Returns all flags with the given [status] (default: pending).
  /// Includes joined chat_messages fields (sender_name, sender_role, content).
  Future<List<FlaggedMessage>> getFlags({
    FlagStatus status = FlagStatus.pending,
  }) async {
    try {
      final response = await _client.from('message_flags').select('''
            *,
            chat_messages!message_id (
              sender_name,
              sender_role,
              content,
              created_at
            )
          ''').eq('status', status.value).order('created_at', ascending: false);

      final flags = (response as List)
          .map((r) => FlaggedMessage.fromJson(r as Map<String, dynamic>))
          .toList();

      // Batch-resolve reporter names
      return _enrichReporterNames(flags);
    } catch (e) {
      debugPrint('ModerationService.getFlags error: $e');
      rethrow;
    }
  }

  /// Returns the total count of pending flags (for badge display).
  Future<int> getPendingCount() async {
    try {
      final rows = await _client
          .from('message_flags')
          .select('id')
          .eq('status', 'pending');
      return (rows as List).length;
    } catch (e) {
      debugPrint('ModerationService.getPendingCount error: $e');
      return 0;
    }
  }

  /// Fetches surrounding messages in the same conversation so the admin
  /// can see the context of the flagged message.
  Future<List<Map<String, dynamic>>> getMessageContext({
    required String conversationId,
    required String messageId,
    int surroundingCount = 5,
  }) async {
    try {
      // Get the flagged message's timestamp
      final flagged = await _client
          .from('chat_messages')
          .select('created_at')
          .eq('id', messageId)
          .single();
      final pivot = flagged['created_at'] as String;

      // Messages before (ascending so oldest first)
      final before = await _client
          .from('chat_messages')
          .select()
          .eq('conversation_id', conversationId)
          .lt('created_at', pivot)
          .order('created_at', ascending: false)
          .limit(surroundingCount);

      // The flagged message itself
      final self = await _client
          .from('chat_messages')
          .select()
          .eq('id', messageId)
          .limit(1);

      // Messages after
      final after = await _client
          .from('chat_messages')
          .select()
          .eq('conversation_id', conversationId)
          .gt('created_at', pivot)
          .order('created_at', ascending: true)
          .limit(surroundingCount);

      return [
        ...List<Map<String, dynamic>>.from(before).reversed,
        ...List<Map<String, dynamic>>.from(self),
        ...List<Map<String, dynamic>>.from(after),
      ];
    } catch (e) {
      debugPrint('ModerationService.getMessageContext error: $e');
      return [];
    }
  }

  // ── Resolution actions ────────────────────────────────────────────────

  /// Dismiss a flag as a false alarm.  No content is removed.
  Future<void> dismissFlag(String flagId) async {
    final adminId = _requireAdminId();
    await _resolveFlag(flagId, FlagResolution.dismissed, adminId);
    await _auditLog(adminId, 'moderation_dismiss', flagId: flagId);
  }

  /// Delete the offending message (set is_deleted = true on chat_messages)
  /// and resolve the flag.
  Future<void> deleteMessage(FlaggedMessage flag) async {
    final adminId = _requireAdminId();

    // 1. Soft-delete message content
    await _client.from('chat_messages').update({
      'content': '[Message removed by moderator]',
      'is_deleted': true,
    }).eq('id', flag.messageId);

    // 2. Resolve the flag
    await _resolveFlag(flag.id, FlagResolution.deleted, adminId);

    // 3. Notify the sender
    await _notify(
      userId: flag.senderId,
      title: 'Message Removed',
      body:
          'A message you sent was removed by a moderator for violating community guidelines (${flag.reason.label}).',
      type: 'moderation_action',
    );

    // 4. Audit log
    await _auditLog(
      adminId,
      'moderation_delete_message',
      flagId: flag.id,
      targetUserId: flag.senderId,
    );
  }

  /// Suspend the sender — sets profiles.is_active = false so the user
  /// is blocked from logging in next time auth is checked.
  Future<void> suspendUser(FlaggedMessage flag) async {
    final adminId = _requireAdminId();

    // 1. Deactivate user
    await _client
        .from('profiles')
        .update({'is_active': false}).eq('user_id', flag.senderId);

    // 2. Soft-delete the offending message too
    await _client.from('chat_messages').update({
      'content': '[Message removed by moderator]',
      'is_deleted': true,
    }).eq('id', flag.messageId);

    // 3. Resolve the flag
    await _resolveFlag(flag.id, FlagResolution.suspended, adminId);

    // 4. Notify sender
    await _notify(
      userId: flag.senderId,
      title: 'Account Suspended',
      body:
          'Your account has been suspended due to a community-guidelines violation (${flag.reason.label}). Contact support for more information.',
      type: 'moderation_action',
    );

    // 5. Audit log
    await _auditLog(
      adminId,
      'moderation_suspend_user',
      flagId: flag.id,
      targetUserId: flag.senderId,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  String _requireAdminId() {
    final id = SupabaseService.currentUserId;
    if (id == null) throw Exception('Admin not authenticated');
    return id;
  }

  Future<void> _resolveFlag(
    String flagId,
    FlagResolution resolution,
    String adminId,
  ) async {
    await _client.from('message_flags').update({
      'status': 'resolved',
      'resolution': resolution.value,
      'resolved_by': adminId,
      'resolved_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', flagId);
  }

  Future<void> _notify({
    required String userId,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      await _client.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'type': type,
        'is_read': false,
      });
    } catch (_) {
      // Best-effort notification
    }
  }

  Future<void> _auditLog(
    String adminId,
    String action, {
    String? flagId,
    String? targetUserId,
  }) async {
    try {
      await _client.from('admin_audit_log').insert({
        'admin_user_id': adminId,
        'action': action,
        'target_user_id': targetUserId,
        'details': {
          'flag_id': flagId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      });
    } catch (_) {
      // Best-effort audit
    }
  }

  /// Batch-resolve reporter names from the profiles table.
  Future<List<FlaggedMessage>> _enrichReporterNames(
    List<FlaggedMessage> flags,
  ) async {
    final reporterIds = flags
        .map((f) => f.reporterId)
        .where((id) => id != null)
        .toSet()
        .toList();
    if (reporterIds.isEmpty) return flags;

    try {
      final profiles = await _client
          .from('profiles')
          .select('user_id, full_name')
          .inFilter('user_id', reporterIds);

      final nameMap = <String, String>{};
      for (final p in profiles) {
        nameMap[p['user_id'] as String] = p['full_name'] as String? ?? '';
      }

      return flags.map((f) {
        if (f.reporterId != null && nameMap.containsKey(f.reporterId)) {
          return f.copyWith(reporterName: nameMap[f.reporterId]);
        }
        return f;
      }).toList();
    } catch (_) {
      return flags;
    }
  }
}
