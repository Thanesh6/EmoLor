import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/models/scheduled_session.dart';

/// UCD037 – Manage Scheduled Sessions (Admin)
///
/// Admin-only service that provides a global view of all sessions and
/// supports force-cancellation with reason, audit logging, and urgent
/// notifications to both therapist and caregiver.
class SessionOversightService {
  final SupabaseClient _client = SupabaseService.client;

  static const _table = 'sessions';

  // ── List sessions ─────────────────────────────────────────────────────

  /// Returns all upcoming sessions platform-wide, optionally filtered by
  /// [statusFilter] and/or [searchQuery] (matches user IDs, title, names).
  /// If [includeAll] is true, past and cancelled sessions are included.
  Future<List<ScheduledSession>> getSessions({
    bool includeAll = false,
    String? searchQuery,
  }) async {
    try {
      var query = _client.from(_table).select();

      if (!includeAll) {
        // Only upcoming scheduled sessions
        query = query
            .eq('status', 'scheduled')
            .gte('session_date', DateTime.now().toUtc().toIso8601String());
      }

      final rows = await query.order('session_date', ascending: true) as List;

      final enriched = await _enrichSessions(rows);

      // Client-side text search across enriched fields
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        return enriched.where((s) {
          return s.title.toLowerCase().contains(q) ||
              (s.caregiverName ?? '').toLowerCase().contains(q) ||
              (s.childName ?? '').toLowerCase().contains(q) ||
              (s.therapistName ?? '').toLowerCase().contains(q) ||
              s.therapistId.toLowerCase().contains(q) ||
              (s.caregiverId ?? '').toLowerCase().contains(q);
        }).toList();
      }

      return enriched;
    } catch (e) {
      debugPrint('SessionOversightService.getSessions error: $e');
      rethrow;
    }
  }

  // ── Force cancel ──────────────────────────────────────────────────────

  /// Force-cancels a session with an admin-provided [reason].
  /// Updates status to 'cancelled', notifies both therapist and caregiver,
  /// and writes an audit-log entry.
  Future<void> forceCancelSession({
    required ScheduledSession session,
    required String reason,
  }) async {
    final adminId = SupabaseService.currentUserId;
    if (adminId == null) throw Exception('Admin not authenticated');

    // 1. Update status
    await _client.from(_table).update({
      'status': 'cancelled',
      'notes': '${session.notes ?? ''}\n[Admin Cancelled: $reason]'.trim(),
    }).eq('id', session.id);

    // 2. Notify therapist
    _notify(
      userId: session.therapistId,
      title: '⚠️ Session Cancelled by Admin',
      body:
          'Your session "${session.title}" on ${_formatDate(session.sessionDate)} '
          'has been cancelled by an administrator.\nReason: $reason',
      type: 'admin_session_cancel',
    );

    // 3. Notify caregiver
    if (session.caregiverId != null) {
      _notify(
        userId: session.caregiverId!,
        title: '⚠️ Session Cancelled by Admin',
        body:
            'The session "${session.title}" on ${_formatDate(session.sessionDate)} '
            'has been cancelled by an administrator.\nReason: $reason',
        type: 'admin_session_cancel',
      );
    }

    // 4. Audit log
    try {
      await _client.from('admin_audit_log').insert({
        'admin_user_id': adminId,
        'action': 'force_cancel_session',
        'target_user_id': session.therapistId,
        'details': {
          'session_id': session.id,
          'session_title': session.title,
          'session_date': session.sessionDate.toIso8601String(),
          'reason': reason,
          'timestamp': DateTime.now().toIso8601String(),
        },
      });
    } catch (_) {
      // Best-effort
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  /// Enrich raw rows with therapist, caregiver, and child display names.
  Future<List<ScheduledSession>> _enrichSessions(List rows) async {
    if (rows.isEmpty) return [];

    // Collect IDs
    final therapistIds =
        rows.map((r) => r['therapist_id'] as String).toSet().toList();

    final caregiverIds = rows
        .where((r) => r['caregiver_id'] != null)
        .map((r) => r['caregiver_id'] as String)
        .toSet()
        .toList();

    final childIds = rows
        .where((r) => r['child_profile_id'] != null)
        .map((r) => r['child_profile_id'] as String)
        .toSet()
        .toList();

    // Batch-fetch names
    final allProfileIds = {...therapistIds, ...caregiverIds}.toList();
    final profileNames = <String, String>{};
    if (allProfileIds.isNotEmpty) {
      final profiles = await _client
          .from('profiles')
          .select('user_id, full_name')
          .inFilter('user_id', allProfileIds) as List;
      for (final p in profiles) {
        profileNames[p['user_id'] as String] =
            (p['full_name'] as String?) ?? 'Unknown';
      }
    }

    final childNames = <String, String>{};
    if (childIds.isNotEmpty) {
      final childProfiles = await _client
          .from('child_profiles')
          .select('id, full_name')
          .inFilter('id', childIds) as List;
      for (final c in childProfiles) {
        childNames[c['id'] as String] = (c['full_name'] as String?) ?? 'Child';
      }
    }

    return rows.map((r) {
      final enriched = Map<String, dynamic>.from(r as Map);
      final tId = r['therapist_id'] as String;
      final cgId = r['caregiver_id'] as String?;
      final chId = r['child_profile_id'] as String?;

      enriched['therapist_name'] = profileNames[tId];
      if (cgId != null) enriched['caregiver_name'] = profileNames[cgId];
      if (chId != null) enriched['child_name'] = childNames[chId];

      return ScheduledSession.fromJson(enriched);
    }).toList();
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
      // Best-effort
    }
  }

  String _formatDate(DateTime d) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }
}
