import 'package:flutter/foundation.dart';

/// UCD035 – Moderate Communication
///
/// Model for a flagged / reported chat message that appears in the
/// admin moderation queue.

// ── Enums ──────────────────────────────────────────────────────────────

/// Why a message was flagged.
enum FlagReason {
  profanity,
  harassment,
  prohibitedKeywords,
  spam,
  inappropriateContent,
  userReport,
  other;

  String get value {
    switch (this) {
      case FlagReason.profanity:
        return 'profanity';
      case FlagReason.harassment:
        return 'harassment';
      case FlagReason.prohibitedKeywords:
        return 'prohibited_keywords';
      case FlagReason.spam:
        return 'spam';
      case FlagReason.inappropriateContent:
        return 'inappropriate_content';
      case FlagReason.userReport:
        return 'user_report';
      case FlagReason.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case FlagReason.profanity:
        return 'Profanity';
      case FlagReason.harassment:
        return 'Harassment';
      case FlagReason.prohibitedKeywords:
        return 'Prohibited Keywords';
      case FlagReason.spam:
        return 'Spam';
      case FlagReason.inappropriateContent:
        return 'Inappropriate Content';
      case FlagReason.userReport:
        return 'User Report';
      case FlagReason.other:
        return 'Other';
    }
  }

  static FlagReason fromString(String s) {
    switch (s) {
      case 'profanity':
        return FlagReason.profanity;
      case 'harassment':
        return FlagReason.harassment;
      case 'prohibited_keywords':
        return FlagReason.prohibitedKeywords;
      case 'spam':
        return FlagReason.spam;
      case 'inappropriate_content':
        return FlagReason.inappropriateContent;
      case 'user_report':
        return FlagReason.userReport;
      default:
        return FlagReason.other;
    }
  }
}

/// Current moderation status of a flag report.
enum FlagStatus {
  pending,
  resolved;

  String get value => name;

  static FlagStatus fromString(String s) {
    if (s == 'resolved') return FlagStatus.resolved;
    return FlagStatus.pending;
  }
}

/// Action the admin took to resolve a flag.
enum FlagResolution {
  dismissed,
  deleted,
  suspended;

  String get value => name;

  String get label {
    switch (this) {
      case FlagResolution.dismissed:
        return 'Dismissed (False Alarm)';
      case FlagResolution.deleted:
        return 'Message Deleted';
      case FlagResolution.suspended:
        return 'User Suspended';
    }
  }

  static FlagResolution? fromString(String? s) {
    if (s == null) return null;
    switch (s) {
      case 'dismissed':
        return FlagResolution.dismissed;
      case 'deleted':
        return FlagResolution.deleted;
      case 'suspended':
        return FlagResolution.suspended;
      default:
        return null;
    }
  }
}

// ── Model ──────────────────────────────────────────────────────────────

@immutable
class FlaggedMessage {
  final String id;
  final String messageId;
  final String conversationId;
  final String senderId;
  final String? reporterId;
  final FlagReason reason;
  final String? details;
  final FlagStatus status;
  final FlagResolution? resolution;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  // Joined fields (populated by service)
  final String senderName;
  final String senderRole;
  final String messageContent;
  final DateTime messageSentAt;
  final String? reporterName;

  const FlaggedMessage({
    required this.id,
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    this.reporterId,
    required this.reason,
    this.details,
    this.status = FlagStatus.pending,
    this.resolution,
    this.resolvedBy,
    this.resolvedAt,
    required this.createdAt,
    this.senderName = 'Unknown',
    this.senderRole = 'unknown',
    this.messageContent = '',
    DateTime? messageSentAt,
    this.reporterName,
  }) : messageSentAt = messageSentAt ?? createdAt;

  factory FlaggedMessage.fromJson(Map<String, dynamic> json) {
    // The service joins chat_messages via message_id and profiles via
    // sender_id so these nested fields may be present.
    final msg = json['chat_messages'] as Map<String, dynamic>?;

    return FlaggedMessage(
      id: json['id'] as String,
      messageId: json['message_id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      reporterId: json['reporter_id'] as String?,
      reason: FlagReason.fromString((json['reason'] as String?) ?? 'other'),
      details: json['details'] as String?,
      status: FlagStatus.fromString((json['status'] as String?) ?? 'pending'),
      resolution: FlagResolution.fromString(json['resolution'] as String?),
      resolvedBy: json['resolved_by'] as String?,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      senderName: msg?['sender_name'] as String? ?? 'Unknown',
      senderRole: msg?['sender_role'] as String? ?? 'unknown',
      messageContent: msg?['content'] as String? ?? '',
      messageSentAt: msg?['created_at'] != null
          ? DateTime.parse(msg!['created_at'] as String)
          : null,
    );
  }

  FlaggedMessage copyWith({
    FlagStatus? status,
    FlagResolution? resolution,
    String? resolvedBy,
    DateTime? resolvedAt,
    String? reporterName,
  }) {
    return FlaggedMessage(
      id: id,
      messageId: messageId,
      conversationId: conversationId,
      senderId: senderId,
      reporterId: reporterId,
      reason: reason,
      details: details,
      status: status ?? this.status,
      resolution: resolution ?? this.resolution,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt,
      senderName: senderName,
      senderRole: senderRole,
      messageContent: messageContent,
      messageSentAt: messageSentAt,
      reporterName: reporterName ?? this.reporterName,
    );
  }
}
