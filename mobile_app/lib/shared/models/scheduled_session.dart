import 'package:flutter/foundation.dart';

/// UCD034 – Schedule Session
///
/// Represents a finalized therapy session stored in the `sessions` table.
/// Used by both therapists (who create/manage) and caregivers (who view).

// ── Enums ──────────────────────────────────────────────────────────────

/// Status lifecycle of a scheduled session.
enum ScheduledSessionStatus {
  scheduled,
  completed,
  cancelled;

  String get value => name;

  String get label {
    switch (this) {
      case ScheduledSessionStatus.scheduled:
        return 'Scheduled';
      case ScheduledSessionStatus.completed:
        return 'Completed';
      case ScheduledSessionStatus.cancelled:
        return 'Cancelled';
    }
  }

  static ScheduledSessionStatus fromString(String s) {
    return ScheduledSessionStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => ScheduledSessionStatus.scheduled,
    );
  }
}

/// Time-slot enum aligned with `session_requests.time_slot`.
enum SessionTimeSlot {
  morning,
  midday,
  afternoon,
  evening;

  String get value => name;

  String get label {
    switch (this) {
      case SessionTimeSlot.morning:
        return 'Morning (8 AM – 11 AM)';
      case SessionTimeSlot.midday:
        return 'Midday (11 AM – 1 PM)';
      case SessionTimeSlot.afternoon:
        return 'Afternoon (1 PM – 4 PM)';
      case SessionTimeSlot.evening:
        return 'Evening (4 PM – 7 PM)';
    }
  }

  String get shortLabel {
    switch (this) {
      case SessionTimeSlot.morning:
        return '8–11 AM';
      case SessionTimeSlot.midday:
        return '11 AM–1 PM';
      case SessionTimeSlot.afternoon:
        return '1–4 PM';
      case SessionTimeSlot.evening:
        return '4–7 PM';
    }
  }

  static SessionTimeSlot fromString(String s) {
    return SessionTimeSlot.values.firstWhere(
      (e) => e.name == s,
      orElse: () => SessionTimeSlot.morning,
    );
  }
}

// ── Model ──────────────────────────────────────────────────────────────

@immutable
class ScheduledSession {
  final String id;
  final String therapistId;
  final String? childProfileId;
  final String? caregiverId;
  final String? sessionRequestId;

  final String title;
  final String? notes;
  final List<String> goals;
  final ScheduledSessionStatus status;

  /// The actual date + time for the session.
  final DateTime sessionDate;

  /// Time-slot bucket for grouping / conflict checks.
  final SessionTimeSlot? timeSlot;

  /// Duration in minutes (default 60).
  final int durationMinutes;

  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Resolved display names (populated by service) ──────────────────

  /// Therapist display name (resolved from profiles table).
  final String? therapistName;

  /// Caregiver display name (resolved from profiles table).
  final String? caregiverName;

  /// Child display name (resolved from child_profiles table).
  final String? childName;

  const ScheduledSession({
    required this.id,
    required this.therapistId,
    this.childProfileId,
    this.caregiverId,
    this.sessionRequestId,
    required this.title,
    this.notes,
    this.goals = const [],
    this.status = ScheduledSessionStatus.scheduled,
    required this.sessionDate,
    this.timeSlot,
    this.durationMinutes = 60,
    required this.createdAt,
    required this.updatedAt,
    this.therapistName,
    this.caregiverName,
    this.childName,
  });

  // ── JSON ────────────────────────────────────────────────────────────

  factory ScheduledSession.fromJson(Map<String, dynamic> json) {
    final goalsRaw = json['goals'];
    List<String> goalsList = [];
    if (goalsRaw is List) {
      goalsList = goalsRaw.map((e) => e.toString()).toList();
    }

    return ScheduledSession(
      id: json['id'] as String,
      therapistId: json['therapist_id'] as String,
      childProfileId: json['child_profile_id'] as String?,
      caregiverId: json['caregiver_id'] as String?,
      sessionRequestId: json['session_request_id'] as String?,
      title: json['title'] as String,
      notes: json['notes'] as String?,
      goals: goalsList,
      status: ScheduledSessionStatus.fromString(json['status'] as String),
      sessionDate: DateTime.parse(json['session_date'] as String),
      timeSlot: json['time_slot'] != null
          ? SessionTimeSlot.fromString(json['time_slot'] as String)
          : null,
      durationMinutes: (json['duration_minutes'] as int?) ?? 60,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      therapistName: json['therapist_name'] as String?,
      caregiverName: json['caregiver_name'] as String?,
      childName: json['child_name'] as String?,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'therapist_id': therapistId,
      'child_profile_id': childProfileId,
      'caregiver_id': caregiverId,
      'session_request_id': sessionRequestId,
      'title': title,
      'notes': notes,
      'goals': goals,
      'status': status.value,
      'session_date': sessionDate.toIso8601String(),
      'time_slot': timeSlot?.value,
      'duration_minutes': durationMinutes,
    };
  }

  ScheduledSession copyWith({
    ScheduledSessionStatus? status,
    String? notes,
    String? title,
  }) {
    return ScheduledSession(
      id: id,
      therapistId: therapistId,
      childProfileId: childProfileId,
      caregiverId: caregiverId,
      sessionRequestId: sessionRequestId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      goals: goals,
      status: status ?? this.status,
      sessionDate: sessionDate,
      timeSlot: timeSlot,
      durationMinutes: durationMinutes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      therapistName: therapistName,
      caregiverName: caregiverName,
      childName: childName,
    );
  }
}

/// Lightweight model for a linked client (caregiver + children) returned
/// when building the participant picker.
@immutable
class LinkedClient {
  final String caregiverId;
  final String caregiverName;
  final List<LinkedChild> children;

  const LinkedClient({
    required this.caregiverId,
    required this.caregiverName,
    this.children = const [],
  });
}

@immutable
class LinkedChild {
  final String id;
  final String name;
  final int? age;

  const LinkedChild({
    required this.id,
    required this.name,
    this.age,
  });
}
