import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../caregiver/models/session_request.dart';

/// UCD033 – Therapist Session Response Service
///
/// Handles therapist-side operations for session requests:
/// • Fetching pending (and historical) requests addressed to the therapist.
/// • Accepting a request (with double-booking validation).
/// • Declining a request (with optional reason).
/// • Sending notifications to the requesting caregiver.
class TherapistSessionService {
  final SupabaseClient _client = SupabaseService.client;

  static const _requestsTable = 'session_requests';

  // ── Fetch requests ────────────────────────────────────────────────────

  /// Returns all session requests addressed to the current therapist.
  ///
  /// [statusFilter] – pass a status to narrow the list (e.g. "pending").
  /// If null, returns all statuses.
  ///
  /// Each row is enriched with `requester_name` from the profiles table
  /// via a server-side join-like approach.
  Future<List<SessionRequest>> getRequestsForTherapist({
    String? statusFilter,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return [];

    try {
      var query =
          _client.from(_requestsTable).select().eq('therapist_id', userId);

      if (statusFilter != null) {
        query = query.eq('status', statusFilter);
      }

      final rows = await query.order('created_at', ascending: false) as List;

      // Collect unique caregiver IDs for name resolution
      final caregiverIds =
          rows.map((r) => r['caregiver_id'] as String).toSet().toList();

      // Batch-fetch caregiver names
      Map<String, String> nameMap = {};
      if (caregiverIds.isNotEmpty) {
        final profiles = await _client
            .from('profiles')
            .select('user_id, full_name')
            .inFilter('user_id', caregiverIds) as List;

        for (final p in profiles) {
          nameMap[p['user_id'] as String] =
              (p['full_name'] as String?) ?? 'Caregiver';
        }
      }

      return rows.map((r) {
        final enriched = Map<String, dynamic>.from(r);
        enriched['requester_name'] =
            nameMap[r['caregiver_id'] as String] ?? 'Caregiver';
        return SessionRequest.fromJson(enriched);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Returns only pending requests – convenience helper for the badge count
  /// and the "Pending Requests" list.
  Future<List<SessionRequest>> getPendingRequests() =>
      getRequestsForTherapist(statusFilter: 'pending');

  /// Returns the count of pending requests for badge display.
  Future<int> getPendingCount() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return 0;

    try {
      final result = await _client
          .from(_requestsTable)
          .select('id')
          .eq('therapist_id', userId)
          .eq('status', 'pending');

      return (result as List).length;
    } catch (_) {
      return 0;
    }
  }

  // ── Accept / Approve ──────────────────────────────────────────────────

  /// Validates the time-slot is free, then updates status to "approved".
  ///
  /// Returns the updated [SessionRequest], or throws on conflict / error.
  Future<SessionRequest> acceptRequest(SessionRequest request) async {
    // 1. Double-booking check
    final hasConflict = await _checkConflict(
      therapistId: request.therapistId,
      date: request.preferredDate,
      timeSlot: request.timeSlot.value,
      excludeId: request.id,
    );

    if (hasConflict) {
      throw SessionConflictException(
        'You already have an approved session on '
        '${_formatDate(request.preferredDate)} (${request.timeSlot.label}). '
        'Please decline or reschedule the conflicting session first.',
      );
    }

    // 2. Update status
    final row = await _client
        .from(_requestsTable)
        .update({'status': SessionRequestStatus.approved.value})
        .eq('id', request.id)
        .select()
        .single();

    // 3. Notify the caregiver
    _notifyCaregiver(
      caregiverId: request.caregiverId,
      title: 'Session Confirmed ✅',
      body: 'Your session on ${_formatDate(request.preferredDate)} '
          '(${request.timeSlot.label}) has been confirmed.',
      type: 'session_confirmed',
    );

    return SessionRequest.fromJson(row);
  }

  // ── Decline ───────────────────────────────────────────────────────────

  /// Updates status to "declined" with an optional reason.
  Future<SessionRequest> declineRequest(
    SessionRequest request, {
    String? reason,
  }) async {
    final updateData = <String, dynamic>{
      'status': SessionRequestStatus.declined.value,
    };
    if (reason != null && reason.trim().isNotEmpty) {
      updateData['decline_reason'] = reason.trim();
    }

    final row = await _client
        .from(_requestsTable)
        .update(updateData)
        .eq('id', request.id)
        .select()
        .single();

    // Notify caregiver
    final reasonText =
        (reason != null && reason.trim().isNotEmpty) ? '\nReason: $reason' : '';

    _notifyCaregiver(
      caregiverId: request.caregiverId,
      title: 'Session Declined',
      body: 'Your session request for ${_formatDate(request.preferredDate)} '
          '(${request.timeSlot.label}) was declined.$reasonText',
      type: 'session_declined',
    );

    return SessionRequest.fromJson(row);
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  /// Checks for a scheduling conflict using the DB function.
  Future<bool> _checkConflict({
    required String therapistId,
    required DateTime date,
    required String timeSlot,
    required String excludeId,
  }) async {
    try {
      final result = await _client.rpc('check_session_conflict', params: {
        'p_therapist_id': therapistId,
        'p_date': date.toIso8601String().split('T').first,
        'p_time_slot': timeSlot,
        'p_exclude_id': excludeId,
      });
      return result == true;
    } catch (_) {
      // If the RPC doesn't exist yet, fall back to a manual query
      return _checkConflictFallback(
        therapistId: therapistId,
        date: date,
        timeSlot: timeSlot,
        excludeId: excludeId,
      );
    }
  }

  /// Manual fallback when the DB function isn't deployed yet.
  Future<bool> _checkConflictFallback({
    required String therapistId,
    required DateTime date,
    required String timeSlot,
    required String excludeId,
  }) async {
    try {
      final dateStr = date.toIso8601String().split('T').first;
      final rows = await _client
          .from(_requestsTable)
          .select('id')
          .eq('therapist_id', therapistId)
          .eq('preferred_date', dateStr)
          .eq('time_slot', timeSlot)
          .eq('status', 'approved')
          .neq('id', excludeId);

      return (rows as List).isNotEmpty;
    } catch (_) {
      return false; // Fail-open so the therapist can still accept
    }
  }

  /// Insert a notification row for the caregiver.
  Future<void> _notifyCaregiver({
    required String caregiverId,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      await _client.from('notifications').insert({
        'user_id': caregiverId,
        'title': title,
        'body': body,
        'type': type,
        'is_read': false,
      });
    } catch (_) {
      // Best-effort – don't block the caller
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

// ── Exceptions ──────────────────────────────────────────────────────────────

/// Thrown when accepting would create a double-booking.
class SessionConflictException implements Exception {
  final String message;
  const SessionConflictException(this.message);

  @override
  String toString() => message;
}
