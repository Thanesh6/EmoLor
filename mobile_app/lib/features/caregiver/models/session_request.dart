import 'package:flutter/foundation.dart';

/// UCD028 / UCD033 – Session Request Model
///
/// Represents a caregiver's formal request for a therapy / consultation
/// session with their linked therapist.  Extended in UCD033 with
/// `declineReason` and `requesterName` for therapist-side response flow.

// ── Enums ──────────────────────────────────────────────────────────────

/// Status lifecycle of a session request.
enum SessionRequestStatus {
  pending,
  approved,
  declined,
  cancelled;

  String get value => name;

  String get label {
    switch (this) {
      case SessionRequestStatus.pending:
        return 'Pending';
      case SessionRequestStatus.approved:
        return 'Approved';
      case SessionRequestStatus.declined:
        return 'Declined';
      case SessionRequestStatus.cancelled:
        return 'Cancelled';
    }
  }

  static SessionRequestStatus fromString(String s) {
    return SessionRequestStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => SessionRequestStatus.pending,
    );
  }
}

/// Predefined time-slot options for the request form.
enum TimeSlot {
  morning,
  midday,
  afternoon,
  evening;

  String get label {
    switch (this) {
      case TimeSlot.morning:
        return 'Morning (8 AM – 11 AM)';
      case TimeSlot.midday:
        return 'Midday (11 AM – 1 PM)';
      case TimeSlot.afternoon:
        return 'Afternoon (1 PM – 4 PM)';
      case TimeSlot.evening:
        return 'Evening (4 PM – 7 PM)';
    }
  }

  String get value => name;

  static TimeSlot fromString(String s) {
    return TimeSlot.values.firstWhere(
      (e) => e.name == s,
      orElse: () => TimeSlot.morning,
    );
  }
}

// ── Model ──────────────────────────────────────────────────────────────

@immutable
class SessionRequest {
  final String id;
  final String caregiverId;
  final String therapistId;

  /// The name of the child this session concerns (informational / for
  /// the therapist push-notification text).
  final String? childName;
  final String? childProfileId;

  /// Preferred date chosen by caregiver.
  final DateTime preferredDate;

  /// Time-slot preference.
  final TimeSlot timeSlot;

  /// Free-text reason / topic for the session.
  final String reason;

  final SessionRequestStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// UCD033 – Optional reason given by therapist when declining.
  final String? declineReason;

  /// Resolved display name of the caregiver who made the request.
  /// Populated by the service when fetching for therapist view.
  final String? requesterName;

  const SessionRequest({
    required this.id,
    required this.caregiverId,
    required this.therapistId,
    this.childName,
    this.childProfileId,
    required this.preferredDate,
    required this.timeSlot,
    required this.reason,
    this.status = SessionRequestStatus.pending,
    required this.createdAt,
    required this.updatedAt,
    this.declineReason,
    this.requesterName,
  });

  // ── JSON ────────────────────────────────────────────────────────────

  factory SessionRequest.fromJson(Map<String, dynamic> json) {
    return SessionRequest(
      id: json['id'] as String,
      caregiverId: json['caregiver_id'] as String,
      therapistId: json['therapist_id'] as String,
      childName: json['child_name'] as String?,
      childProfileId: json['child_profile_id'] as String?,
      preferredDate: DateTime.parse(json['preferred_date'] as String),
      timeSlot: TimeSlot.fromString(json['time_slot'] as String),
      reason: json['reason'] as String,
      status: SessionRequestStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      declineReason: json['decline_reason'] as String?,
      requesterName: json['requester_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caregiver_id': caregiverId,
      'therapist_id': therapistId,
      'child_name': childName,
      'child_profile_id': childProfileId,
      'preferred_date': preferredDate.toIso8601String(),
      'time_slot': timeSlot.value,
      'reason': reason,
      'status': status.value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'decline_reason': declineReason,
    };
  }

  /// Insert-ready map (omits id / timestamps – let the DB generate them).
  Map<String, dynamic> toInsertJson() {
    return {
      'caregiver_id': caregiverId,
      'therapist_id': therapistId,
      'child_name': childName,
      'child_profile_id': childProfileId,
      'preferred_date': preferredDate.toIso8601String(),
      'time_slot': timeSlot.value,
      'reason': reason,
      'status': status.value,
    };
  }

  SessionRequest copyWith({
    SessionRequestStatus? status,
    String? declineReason,
  }) {
    return SessionRequest(
      id: id,
      caregiverId: caregiverId,
      therapistId: therapistId,
      childName: childName,
      childProfileId: childProfileId,
      preferredDate: preferredDate,
      timeSlot: timeSlot,
      reason: reason,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      declineReason: declineReason ?? this.declineReason,
      requesterName: requesterName,
    );
  }
}

/// Lightweight therapist info returned when checking the caregiver's link.
@immutable
class LinkedTherapistInfo {
  final String id;
  final String name;
  final String? email;
  final String? avatarUrl;

  const LinkedTherapistInfo({
    required this.id,
    required this.name,
    this.email,
    this.avatarUrl,
  });

  factory LinkedTherapistInfo.fromJson(Map<String, dynamic> json) {
    return LinkedTherapistInfo(
      id: json['user_id'] as String? ?? json['id'] as String,
      name: (json['full_name'] as String?) ?? 'Therapist',
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
