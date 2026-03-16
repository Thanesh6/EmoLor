import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../models/session_request.dart';

/// UCD028 – Session Request Service
///
/// Handles:
/// • Checking whether the current caregiver is linked to a therapist.
/// • Creating a new session request (status = "pending").
/// • Listing the caregiver's own requests.
/// • (Therapist-side: approve / decline — future UCD).
class SessionRequestService {
  final SupabaseClient _client = SupabaseService.client;

  // ── Table / view names ────────────────────────────────────────────────

  static const _requestsTable = 'session_requests';

  // ── Therapist link check ──────────────────────────────────────────────

  /// Returns the [LinkedTherapistInfo] for the caregiver's linked therapist,
  /// or `null` if no therapist is linked.
  ///
  /// The linking is derived from `therapist_client_link` where the caregiver
  /// is the `client_id` (caregivers are the "clients" of therapists).
  Future<LinkedTherapistInfo?> getLinkedTherapist() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return null;

    try {
      // 1. Check therapist_client_link for a row where this caregiver = client
      final linkRows = await _client
          .from('therapist_client_link')
          .select('therapist_id')
          .eq('client_id', userId)
          .limit(1);

      if ((linkRows as List).isEmpty) return null;

      final therapistId = linkRows[0]['therapist_id'] as String;

      // 2. Fetch therapist profile
      final profile = await _client
          .from('profiles')
          .select()
          .eq('user_id', therapistId)
          .maybeSingle();

      if (profile == null) return null;
      return LinkedTherapistInfo.fromJson(profile);
    } catch (e) {
      // Swallow – caller should interpret null as "not linked"
      return null;
    }
  }

  // ── Create request ────────────────────────────────────────────────────

  /// Submit a new session request.
  ///
  /// * [therapistId] – the linked therapist's user-id.
  /// * [preferredDate] – caregiver-chosen date.
  /// * [timeSlot] – one of the predefined time-slot buckets.
  /// * [reason] – free-text topic / description.
  /// * [childName] – optional, for notification text.
  /// * [childProfileId] – optional FK to child_profiles.
  ///
  /// Returns the saved [SessionRequest].
  Future<SessionRequest> createRequest({
    required String therapistId,
    required DateTime preferredDate,
    required TimeSlot timeSlot,
    required String reason,
    String? childName,
    String? childProfileId,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final data = {
      'caregiver_id': userId,
      'therapist_id': therapistId,
      'child_name': childName,
      'child_profile_id': childProfileId,
      'preferred_date': preferredDate.toIso8601String(),
      'time_slot': timeSlot.value,
      'reason': reason,
      'status': SessionRequestStatus.pending.value,
    };

    final row =
        await _client.from(_requestsTable).insert(data).select().single();

    // Fire-and-forget push notification (Edge Function or DB trigger)
    _notifyTherapist(therapistId, childName);

    return SessionRequest.fromJson(row);
  }

  // ── List caregiver's requests ─────────────────────────────────────────

  /// Returns all session requests created by the current caregiver,
  /// ordered newest-first.
  Future<List<SessionRequest>> getMyRequests() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return [];

    final rows = await _client
        .from(_requestsTable)
        .select()
        .eq('caregiver_id', userId)
        .order('created_at', ascending: false);

    return (rows as List).map((r) => SessionRequest.fromJson(r)).toList();
  }

  /// Cancel a pending request.
  Future<void> cancelRequest(String requestId) async {
    await _client.from(_requestsTable).update(
        {'status': SessionRequestStatus.cancelled.value}).eq('id', requestId);
  }

  // ── Notification helper (best-effort) ─────────────────────────────────

  /// Inserts a row into `notifications` so the therapist sees it in-app.
  /// Push notifications are handled by a Supabase Edge Function trigger
  /// on the `session_requests` table.
  Future<void> _notifyTherapist(String therapistId, String? childName) async {
    try {
      final label = childName ?? 'a caregiver';
      await _client.from('notifications').insert({
        'user_id': therapistId,
        'title': 'New Session Request',
        'body': 'New Session Request from $label',
        'type': 'session_request',
        'is_read': false,
      });
    } catch (_) {
      // Best-effort – don't block the caller
    }
  }
}
