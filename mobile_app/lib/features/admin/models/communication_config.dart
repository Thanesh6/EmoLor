import 'package:flutter/foundation.dart';

/// UCD036 – Manage Communication Settings
///
/// Typed model representing the global communication configuration
/// stored in the `communication_config` table (key → JSONB value).

@immutable
class CommunicationConfig {
  /// Maximum attachment file size in megabytes.
  final int maxAttachmentSizeMb;

  /// List of allowed file extensions (e.g. jpg, pdf, docx).
  final List<String> allowedFileTypes;

  /// Number of days before chat history is auto-deleted (0 = never).
  final int chatHistoryRetentionDays;

  /// Maximum character length for a single message.
  final int maxMessageLength;

  /// Whether media upload is globally enabled.
  final bool mediaUploadEnabled;

  /// Whether the profanity filter is active.
  final bool profanityFilterEnabled;

  const CommunicationConfig({
    this.maxAttachmentSizeMb = 10,
    this.allowedFileTypes = const [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'pdf',
      'doc',
      'docx',
    ],
    this.chatHistoryRetentionDays = 365,
    this.maxMessageLength = 2000,
    this.mediaUploadEnabled = true,
    this.profanityFilterEnabled = true,
  });

  /// Build from a list of raw DB rows (`[{key, value}, ...]`).
  factory CommunicationConfig.fromRows(List<Map<String, dynamic>> rows) {
    int maxSize = 10;
    List<String> fileTypes = const [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'pdf',
      'doc',
      'docx'
    ];
    int retention = 365;
    int maxMsg = 2000;
    bool mediaEnabled = true;
    bool profanity = true;

    for (final row in rows) {
      final key = row['key'] as String;
      final value = row['value']; // Already parsed JSONB

      switch (key) {
        case 'max_attachment_size_mb':
          maxSize = _toInt(value, 10);
          break;
        case 'allowed_file_types':
          if (value is List) {
            fileTypes = value.map((e) => e.toString()).toList();
          }
          break;
        case 'chat_history_retention_days':
          retention = _toInt(value, 365);
          break;
        case 'max_message_length':
          maxMsg = _toInt(value, 2000);
          break;
        case 'media_upload_enabled':
          mediaEnabled = _toBool(value, true);
          break;
        case 'profanity_filter_enabled':
          profanity = _toBool(value, true);
          break;
      }
    }

    return CommunicationConfig(
      maxAttachmentSizeMb: maxSize,
      allowedFileTypes: fileTypes,
      chatHistoryRetentionDays: retention,
      maxMessageLength: maxMsg,
      mediaUploadEnabled: mediaEnabled,
      profanityFilterEnabled: profanity,
    );
  }

  /// Convert to a map of DB key → JSONB-friendly value for upsert.
  Map<String, dynamic> toKeyValueMap() {
    return {
      'max_attachment_size_mb': maxAttachmentSizeMb,
      'allowed_file_types': allowedFileTypes,
      'chat_history_retention_days': chatHistoryRetentionDays,
      'max_message_length': maxMessageLength,
      'media_upload_enabled': mediaUploadEnabled,
      'profanity_filter_enabled': profanityFilterEnabled,
    };
  }

  CommunicationConfig copyWith({
    int? maxAttachmentSizeMb,
    List<String>? allowedFileTypes,
    int? chatHistoryRetentionDays,
    int? maxMessageLength,
    bool? mediaUploadEnabled,
    bool? profanityFilterEnabled,
  }) {
    return CommunicationConfig(
      maxAttachmentSizeMb: maxAttachmentSizeMb ?? this.maxAttachmentSizeMb,
      allowedFileTypes: allowedFileTypes ?? this.allowedFileTypes,
      chatHistoryRetentionDays:
          chatHistoryRetentionDays ?? this.chatHistoryRetentionDays,
      maxMessageLength: maxMessageLength ?? this.maxMessageLength,
      mediaUploadEnabled: mediaUploadEnabled ?? this.mediaUploadEnabled,
      profanityFilterEnabled:
          profanityFilterEnabled ?? this.profanityFilterEnabled,
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────

  static int _toInt(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static bool _toBool(dynamic v, bool fallback) {
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    return fallback;
  }
}
