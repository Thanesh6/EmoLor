import 'package:flutter/foundation.dart';

/// UCD029 – Add Message / Feedback
///
/// Model for a single chat message exchanged between a caregiver and a
/// therapist within a secure conversation.

// ── Enums ──────────────────────────────────────────────────────────────

/// The type / purpose of a message.
enum MessageType {
  text,
  clinicalNote,
  feedback,
  media;

  String get value => name;

  String get label {
    switch (this) {
      case MessageType.text:
        return 'Message';
      case MessageType.clinicalNote:
        return 'Clinical Note';
      case MessageType.feedback:
        return 'Feedback';
      case MessageType.media:
        return 'Attachment';
    }
  }

  static MessageType fromString(String s) {
    return MessageType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => MessageType.text,
    );
  }
}

// ── Model ──────────────────────────────────────────────────────────────

@immutable
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'caregiver' | 'therapist'
  final String content;
  final MessageType messageType;
  final bool isRead;
  final DateTime createdAt;

  // UCD030 – Media attachment fields
  final String? mediaUrl;
  final String? mediaType; // 'image' | 'document'
  final String? fileName;
  final int? fileSizeBytes;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderRole = 'caregiver',
    required this.content,
    this.messageType = MessageType.text,
    this.isRead = false,
    required this.createdAt,
    this.mediaUrl,
    this.mediaType,
    this.fileName,
    this.fileSizeBytes,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: (json['sender_name'] as String?) ?? 'Unknown',
      senderRole: (json['sender_role'] as String?) ?? 'caregiver',
      content: json['content'] as String,
      messageType:
          MessageType.fromString((json['message_type'] as String?) ?? 'text'),
      isRead: (json['is_read'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String?,
      fileName: json['file_name'] as String?,
      fileSizeBytes: json['file_size_bytes'] as int?,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'conversation_id': conversationId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_role': senderRole,
      'content': content,
      'message_type': messageType.value,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (mediaType != null) 'media_type': mediaType,
      if (fileName != null) 'file_name': fileName,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
    };
  }
}

// ── Conversation ───────────────────────────────────────────────────────

/// A conversation between two users (typically caregiver ↔ therapist).
@immutable
class Conversation {
  final String id;
  final String participantOneId;
  final String participantTwoId;
  final String? participantOneName;
  final String? participantTwoName;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final DateTime createdAt;

  /// UCD031 – Number of unread messages for the current user.
  final int unreadCount;

  const Conversation({
    required this.id,
    required this.participantOneId,
    required this.participantTwoId,
    this.participantOneName,
    this.participantTwoName,
    this.lastMessagePreview,
    this.lastMessageAt,
    required this.createdAt,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      participantOneId: json['participant_one_id'] as String,
      participantTwoId: json['participant_two_id'] as String,
      participantOneName: json['participant_one_name'] as String?,
      participantTwoName: json['participant_two_name'] as String?,
      lastMessagePreview: json['last_message_preview'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      unreadCount: (json['unread_count'] as int?) ?? 0,
    );
  }

  /// Creates a copy with updated unread count.
  Conversation copyWith({int? unreadCount}) {
    return Conversation(
      id: id,
      participantOneId: participantOneId,
      participantTwoId: participantTwoId,
      participantOneName: participantOneName,
      participantTwoName: participantTwoName,
      lastMessagePreview: lastMessagePreview,
      lastMessageAt: lastMessageAt,
      createdAt: createdAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  /// Returns the other participant's name given the current user's id.
  String otherParticipantName(String myUserId) {
    if (myUserId == participantOneId) {
      return participantTwoName ?? 'Contact';
    }
    return participantOneName ?? 'Contact';
  }

  /// Returns the other participant's user_id.
  String otherParticipantId(String myUserId) {
    return myUserId == participantOneId ? participantTwoId : participantOneId;
  }

  /// Returns the other participant's role label.
  String otherParticipantRole(String myUserId) {
    // We don't store role in the conversation row, so return a generic label.
    return 'Contact';
  }

  /// Whether this conversation has any unread messages.
  bool get hasUnread => unreadCount > 0;
}
