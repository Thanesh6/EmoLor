import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/models/scheduled_session.dart';

/// UCD034 – Session Scheduling Service
///
/// Handles:
/// • Fetching the therapist's linked clients and children (for participant picker).
/// • Checking for slot conflicts before scheduling.
/// • Creating a new scheduled session (blocking the time-slot).
/// • Listing upcoming / past sessions.
/// • Cancelling a scheduled session.
/// • Notifying the other party.
class SessionSchedulingService {
  final SupabaseClient _client = SupabaseService.client;

  static const _sessionsTable = 'sessions';

  // ── Linked clients / children ─────────────────────────────────────────

  /// Returns the therapist's linked clients (caregivers) with their children.
  /// Used by the participant picker in the scheduler form.
  Future<List<LinkedClient>> getLinkedClients() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return [];

    try {
      // 1. Get caregiver IDs from therapist_client_link
      final linkRows = await _client
          .from('therapist_client_link')
          .select('client_id')
          .eq('therapist_id', userId) as List;

      if (linkRows.isEmpty) return [];

      final caregiverIds =
          linkRows.map((r) => r['client_id'] as String).toList();

      // 2. Fetch caregiver profiles
      final profiles = await _client
          .from('profiles')
          .select('user_id, full_name')
          .inFilter('user_id', caregiverIds) as List;

      final nameMap = <String, String>{};
      for (final p in profiles) {
        nameMap[p['user_id'] as String] =
            (p['full_name'] as String?) ?? 'Caregiver';
      }

      // 3. Fetch children for each caregiver
      final children = await _client
          .from('child_profiles')
          .select('id, full_name, age, caregiver_id')
          .inFilter('caregiver_id', caregiverIds)
          .eq('is_active', true) as List;

      // Group children by caregiver
      final childrenMap = <String, List<LinkedChild>>{};
      for (final c in children) {
        final cgId = c['caregiver_id'] as String;
        childrenMap.putIfAbsent(cgId, () => []);
        childrenMap[cgId]!.add(LinkedChild(
          id: c['id'] as String,
          name: (c['full_name'] as String?) ?? 'Child',
          age: c['age'] as int?,
        ));
      }

      // Build result
      return caregiverIds.map((cgId) {
        return LinkedClient(
          caregiverId: cgId,
          caregiverName: nameMap[cgId] ?? 'Caregiver',
          children: childrenMap[cgId] ?? [],
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // ── Slot conflict check ───────────────────────────────────────────────

  /// Returns `true` when the therapist already has a scheduled (non-cancelled)
  /// session for the given date + time-slot.
  Future<bool> hasConflict({
    required DateTime date,
    required SessionTimeSlot timeSlot,
    String? excludeId,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return false;

    try {
      // Try the DB function first
      final result = await _client.rpc('check_schedule_conflict', params: {
        'p_therapist_id': userId,
        'p_date': date.toIso8601String().split('T').first,
        'p_time_slot': timeSlot.value,
        'p_exclude_id': excludeId,
      });
      return result == true;
    } catch (_) {
      // Fallback: manual query
      return _hasConflictFallback(
        therapistId: userId,
        date: date,
        timeSlot: timeSlot,
        excludeId: excludeId,
      );
    }
  }

  Future<bool> _hasConflictFallback({
    required String therapistId,
    required DateTime date,
    required SessionTimeSlot timeSlot,
    String? excludeId,
  }) async {
    try {
      final dateStr = date.toIso8601String().split('T').first;
      var query = _client
          .from(_sessionsTable)
          .select('id')
          .eq('therapist_id', therapistId)
          .eq('time_slot', timeSlot.value)
          .eq('status', 'scheduled')
          .gte('session_date', '${dateStr}T00:00:00')
          .lt('session_date', '${dateStr}T23:59:59');

      if (excludeId != null) {
        query = query.neq('id', excludeId);
      }

      final rows = await query as List;
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Returns which time-slots are already taken on a particular date.
  /// Used to dim unavailable slots in the scheduler calendar.
  Future<Set<SessionTimeSlot>> getTakenSlots(DateTime date) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return {};

    try {
      final dateStr = date.toIso8601String().split('T').first;
      final rows = await _client
          .from(_sessionsTable)
          .select('time_slot')
          .eq('therapist_id', userId)
          .eq('status', 'scheduled')
          .gte('session_date', '${dateStr}T00:00:00')
          .lt('session_date', '${dateStr}T23:59:59') as List;

      return rows
          .where((r) => r['time_slot'] != null)
          .map((r) => SessionTimeSlot.fromString(r['time_slot'] as String))
          .toSet();
    } catch (_) {
      return {};
    }
  }

  // ── Schedule session ──────────────────────────────────────────────────

  /// Creates a new scheduled session.  Checks for conflicts first.
  ///
  /// Throws [SlotTakenException] if the slot was just booked by another user.
  Future<ScheduledSession> scheduleSession({
    required DateTime date,
    required SessionTimeSlot timeSlot,
    required String title,
    String? notes,
    String? caregiverId,
    String? childProfileId,
    String? sessionRequestId,
    int durationMinutes = 60,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    // 1. Conflict check
    final conflict = await hasConflict(date: date, timeSlot: timeSlot);
    if (conflict) {
      throw const SlotTakenException(
        'Slot no longer available. Please choose another time.',
      );
    }

    // 2. Build session_date timestamp from date + time-slot start
    final sessionDate = _buildSessionDateTime(date, timeSlot);

    // 3. Insert
    final data = <String, dynamic>{
      'therapist_id': userId,
      'title': title,
      'notes': notes,
      'status': 'scheduled',
      'session_date': sessionDate.toIso8601String(),
      'time_slot': timeSlot.value,
      'duration_minutes': durationMinutes,
      'caregiver_id': caregiverId,
      'child_profile_id': childProfileId,
      'session_request_id': sessionRequestId,
    };

    final row =
        await _client.from(_sessionsTable).insert(data).select().single();

    // 4. Notify caregiver (fire-and-forget)
    if (caregiverId != null) {
      _notifyUser(
        userId: caregiverId,
        title: 'Session Scheduled 📅',
        body: 'A session "$title" has been scheduled for '
            '${_formatDate(sessionDate)} (${timeSlot.label}).',
        type: 'session_scheduled',
      );
    }

    return ScheduledSession.fromJson(row);
  }

  // ── List sessions ─────────────────────────────────────────────────────

  /// Returns the therapist's sessions (upcoming first, then past).
  /// Also enriches with caregiver/child display names.
  Future<List<ScheduledSession>> getTherapistSessions({
    bool upcomingOnly = false,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return [];

    try {
      var query =
          _client.from(_sessionsTable).select().eq('therapist_id', userId);

      if (upcomingOnly) {
        query = query
            .eq('status', 'scheduled')
            .gte('session_date', DateTime.now().toIso8601String());
      }

      final rows = await query.order('session_date', ascending: true) as List;

      return _enrichSessions(rows);
    } catch (_) {
      return [];
    }
  }

  /// Returns sessions for a caregiver — only their own.
  Future<List<ScheduledSession>> getCaregiverSessions() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return [];

    try {
      final rows = await _client
          .from(_sessionsTable)
          .select()
          .eq('caregiver_id', userId)
          .order('session_date', ascending: true) as List;

      return _enrichSessions(rows);
    } catch (_) {
      return [];
    }
  }

  /// Returns sessions for a specific date (for the calendar day view).
  Future<List<ScheduledSession>> getSessionsForDate(DateTime date) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return [];

    try {
      final dateStr = date.toIso8601String().split('T').first;
      final rows = await _client
          .from(_sessionsTable)
          .select()
          .eq('therapist_id', userId)
          .gte('session_date', '${dateStr}T00:00:00')
          .lt('session_date', '${dateStr}T23:59:59')
          .order('session_date', ascending: true) as List;

      return _enrichSessions(rows);
    } catch (_) {
      return [];
    }
  }

  /// Returns dates that have at least one session (for calendar markers).
  Future<Set<DateTime>> getSessionDates({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return {};

    try {
      final rows = await _client
          .from(_sessionsTable)
          .select('session_date')
          .eq('therapist_id', userId)
          .gte('session_date', rangeStart.toIso8601String())
          .lte('session_date', rangeEnd.toIso8601String()) as List;

      return rows.map((r) {
        final d = DateTime.parse(r['session_date'] as String);
        return DateTime(d.year, d.month, d.day);
      }).toSet();
    } catch (_) {
      return {};
    }
  }

  // ── Cancel ────────────────────────────────────────────────────────────

  /// Cancel a scheduled session.
  Future<void> cancelSession(ScheduledSession session) async {
    await _client
        .from(_sessionsTable)
        .update({'status': 'cancelled'}).eq('id', session.id);

    // Notify caregiver
    if (session.caregiverId != null) {
      _notifyUser(
        userId: session.caregiverId!,
        title: 'Session Cancelled',
        body: 'The session "${session.title}" on '
            '${_formatDate(session.sessionDate)} has been cancelled.',
        type: 'session_cancelled',
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  /// Enrich raw rows with caregiver + child display names.
  Future<List<ScheduledSession>> _enrichSessions(List rows) async {
    if (rows.isEmpty) return [];

    // Collect IDs
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
    final caregiverNames = <String, String>{};
    if (caregiverIds.isNotEmpty) {
      final profiles = await _client
          .from('profiles')
          .select('user_id, full_name')
          .inFilter('user_id', caregiverIds) as List;
      for (final p in profiles) {
        caregiverNames[p['user_id'] as String] =
            (p['full_name'] as String?) ?? 'Caregiver';
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
      final enriched = Map<String, dynamic>.from(r);
      final cgId = r['caregiver_id'] as String?;
      final chId = r['child_profile_id'] as String?;
      if (cgId != null) enriched['caregiver_name'] = caregiverNames[cgId];
      if (chId != null) enriched['child_name'] = childNames[chId];
      return ScheduledSession.fromJson(enriched);
    }).toList();
  }

  /// Maps a time-slot to a concrete start-of-slot hour.
  DateTime _buildSessionDateTime(DateTime date, SessionTimeSlot slot) {
    final hour = switch (slot) {
      SessionTimeSlot.morning => 8,
      SessionTimeSlot.midday => 11,
      SessionTimeSlot.afternoon => 13,
      SessionTimeSlot.evening => 16,
    };
    return DateTime(date.year, date.month, date.day, hour);
  }

  Future<void> _notifyUser({
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

// ── Exceptions ──────────────────────────────────────────────────────────────

/// Thrown when the selected slot was just booked by another user.
class SlotTakenException implements Exception {
  final String message;
  const SlotTakenException(this.message);

  @override
  String toString() => message;
}
