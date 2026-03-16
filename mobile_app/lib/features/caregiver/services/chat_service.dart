import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../models/chat_message.dart';

/// UCD029 – Chat Service
///
/// Handles:
/// • Finding or creating a conversation between two users.
/// • Sending messages (validated, timestamped, stored in Supabase).
/// • Loading message history.
/// • Real-time subscription for incoming messages.
/// • Marking messages as read.
/// • Sending push-notification rows for the recipient.
class ChatService {
  final SupabaseClient _client = SupabaseService.client;

  // ── Tables ────────────────────────────────────────────────────────────

  static const _conversations = 'conversations';
  static const _messages = 'chat_messages';

  // ── UCD030 – Media upload constants ──────────────────────────────────

  static const String _storageBucket = 'chat-media';
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const List<String> allowedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'pdf',
    'doc',
    'docx',
  ];
  static const List<String> imageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
  ];

  // ── Conversation helpers ──────────────────────────────────────────────

  /// Find the existing conversation between [userA] and [userB],
  /// or create a new one if none exists. Returns the conversation row.
  Future<Conversation> getOrCreateConversation({
    required String userAId,
    required String userAName,
    required String userBId,
    required String userBName,
  }) async {
    // Check both orderings
    final existing = await _client
        .from(_conversations)
        .select()
        .or('and(participant_one_id.eq.$userAId,participant_two_id.eq.$userBId),'
            'and(participant_one_id.eq.$userBId,participant_two_id.eq.$userAId)')
        .maybeSingle();

    if (existing != null) return Conversation.fromJson(existing);

    // Create new conversation
    final row = await _client
        .from(_conversations)
        .insert({
          'participant_one_id': userAId,
          'participant_two_id': userBId,
          'participant_one_name': userAName,
          'participant_two_name': userBName,
        })
        .select()
        .single();

    return Conversation.fromJson(row);
  }

  /// Get all conversations for the current user, enriched with unread counts.
  /// UCD031 – Conversation thread list with unread badges.
  Future<List<Conversation>> getMyConversations() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return [];

    final rows = await _client
        .from(_conversations)
        .select()
        .or('participant_one_id.eq.$userId,participant_two_id.eq.$userId')
        .order('last_message_at', ascending: false);

    final conversations =
        (rows as List).map((r) => Conversation.fromJson(r)).toList();

    // Enrich each conversation with its unread count
    final enriched = <Conversation>[];
    for (final convo in conversations) {
      final count = await getUnreadCount(convo.id);
      enriched.add(convo.copyWith(unreadCount: count));
    }
    return enriched;
  }

  // ── UCD031 – Unread count helpers ─────────────────────────────────────

  /// Get the number of unread messages in a specific conversation
  /// for the current user.
  Future<int> getUnreadCount(String conversationId) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return 0;

    try {
      final result = await _client
          .from(_messages)
          .select()
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId)
          .eq('is_read', false);

      return (result as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Get the total number of unread messages across all conversations
  /// for the current user.  Used for the dashboard badge.
  Future<int> getTotalUnreadCount() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return 0;

    try {
      // Get all conversation IDs for this user
      final convos = await _client
          .from(_conversations)
          .select('id')
          .or('participant_one_id.eq.$userId,participant_two_id.eq.$userId');

      if ((convos as List).isEmpty) return 0;

      final convoIds = convos.map((c) => c['id'] as String).toList();

      final result = await _client
          .from(_messages)
          .select()
          .inFilter('conversation_id', convoIds)
          .neq('sender_id', userId)
          .eq('is_read', false);

      return (result as List).length;
    } catch (_) {
      return 0;
    }
  }

  // ── Messages ──────────────────────────────────────────────────────────

  /// Load message history for a conversation, ordered oldest-first.
  Future<List<ChatMessage>> getMessages(String conversationId,
      {int limit = 100}) async {
    final rows = await _client
        .from(_messages)
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .limit(limit);

    return (rows as List).map((r) => ChatMessage.fromJson(r)).toList();
  }

  /// Send a new message.
  ///
  /// Validates content is non-empty, inserts the row, updates conversation's
  /// last-message metadata, and fires a notification for the recipient.
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String recipientId,
    required String content,
    MessageType messageType = MessageType.text,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    // ── Validate ────────────────────────────────────────────────────
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw Exception('Message cannot be empty');
    }

    // ── Fetch sender name ───────────────────────────────────────────
    String senderName = 'User';
    String senderRole = 'caregiver';
    try {
      final profile = await _client
          .from('profiles')
          .select('full_name, role')
          .eq('user_id', userId)
          .maybeSingle();
      if (profile != null) {
        senderName = (profile['full_name'] as String?) ?? 'User';
        senderRole = (profile['role'] as String?) ?? 'caregiver';
      }
    } catch (_) {}

    // ── Insert message ──────────────────────────────────────────────
    final row = await _client
        .from(_messages)
        .insert({
          'conversation_id': conversationId,
          'sender_id': userId,
          'sender_name': senderName,
          'sender_role': senderRole,
          'content': trimmed,
          'message_type': messageType.value,
        })
        .select()
        .single();

    // ── Update conversation last-message metadata ───────────────────
    final preview =
        trimmed.length > 80 ? '${trimmed.substring(0, 80)}…' : trimmed;
    await _client.from(_conversations).update({
      'last_message_preview': preview,
      'last_message_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', conversationId);

    // ── Notify recipient (best-effort) ──────────────────────────────
    _notifyRecipient(recipientId, senderName);

    return ChatMessage.fromJson(row);
  }
  // ── UCD030 – Media upload & send ─────────────────────────────────────────

  /// Validate a picked file against size and format constraints.
  /// Throws [Exception] with user-friendly message on violation.
  void validateFile(PlatformFile file) {
    // Size check
    if ((file.size) > maxFileSizeBytes) {
      throw Exception('File size too large. Max limit is 10MB.');
    }
    // Extension check
    final ext = (file.extension ?? '').toLowerCase();
    if (ext.isEmpty || !allowedExtensions.contains(ext)) {
      throw Exception(
          'Invalid format. Please upload images or documents only.');
    }
  }

  /// Whether [extension] represents an image format.
  bool isImageExtension(String? extension) {
    if (extension == null) return false;
    return imageExtensions.contains(extension.toLowerCase());
  }

  /// Upload a file to Supabase Storage and return the public URL.
  Future<String> uploadMedia({
    required PlatformFile file,
    required String conversationId,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final filePath = file.path;
    if (filePath == null) throw Exception('File path not available');

    final ext = (file.extension ?? 'bin').toLowerCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '$conversationId/${userId}_$timestamp.$ext';

    await _client.storage.from(_storageBucket).upload(
          storagePath,
          File(filePath),
          fileOptions: const FileOptions(upsert: true),
        );

    final publicUrl =
        _client.storage.from(_storageBucket).getPublicUrl(storagePath);
    return publicUrl;
  }

  /// Pick a file, validate, upload, and send as a media message.
  Future<ChatMessage> sendMediaMessage({
    required String conversationId,
    required String recipientId,
    required PlatformFile file,
    String? caption,
  }) async {
    // Validate
    validateFile(file);

    // Upload
    final mediaUrl = await uploadMedia(
      file: file,
      conversationId: conversationId,
    );

    final isImage = isImageExtension(file.extension);
    final content = caption?.trim().isNotEmpty == true ? caption! : (file.name);

    // Send as a message with media metadata
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    String senderName = 'User';
    String senderRole = 'caregiver';
    try {
      final profile = await _client
          .from('profiles')
          .select('full_name, role')
          .eq('user_id', userId)
          .maybeSingle();
      if (profile != null) {
        senderName = (profile['full_name'] as String?) ?? 'User';
        senderRole = (profile['role'] as String?) ?? 'caregiver';
      }
    } catch (_) {}

    final row = await _client
        .from(_messages)
        .insert({
          'conversation_id': conversationId,
          'sender_id': userId,
          'sender_name': senderName,
          'sender_role': senderRole,
          'content': content,
          'message_type': MessageType.media.value,
          'media_url': mediaUrl,
          'media_type': isImage ? 'image' : 'document',
          'file_name': file.name,
          'file_size_bytes': file.size,
        })
        .select()
        .single();

    // Update conversation last-message metadata
    final preview = isImage ? '📷 Photo' : '📄 ${file.name}';
    await _client.from(_conversations).update({
      'last_message_preview': preview,
      'last_message_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', conversationId);

    // Notify recipient
    _notifyRecipient(recipientId, senderName);

    return ChatMessage.fromJson(row);
  }
  // ── Real-time subscription ────────────────────────────────────────────

  /// Subscribe to new messages in a conversation.
  /// Returns a [RealtimeChannel] — caller should call `.unsubscribe()` on
  /// dispose.
  RealtimeChannel subscribeToMessages(
    String conversationId,
    void Function(ChatMessage message) onNewMessage,
  ) {
    final channel = _client
        .channel('chat:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: _messages,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final newRow = payload.newRecord;
            if (newRow.isNotEmpty) {
              onNewMessage(ChatMessage.fromJson(newRow));
            }
          },
        )
        .subscribe();

    return channel;
  }

  // ── Mark read ─────────────────────────────────────────────────────────

  /// Mark all messages in a conversation as read by the current user.
  Future<void> markAsRead(String conversationId) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    await _client
        .from(_messages)
        .update({'is_read': true})
        .eq('conversation_id', conversationId)
        .neq('sender_id', userId)
        .eq('is_read', false);
  }

  // ── Get linked contact ────────────────────────────────────────────────

  /// For a caregiver: find their linked therapist.
  /// For a therapist: find their linked clients.
  /// Returns a list of {user_id, full_name, role, email, avatar_url}.
  Future<List<Map<String, dynamic>>> getLinkedContacts() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return [];

    // Determine current user's role
    final myProfile = await _client
        .from('profiles')
        .select('role')
        .eq('user_id', userId)
        .maybeSingle();

    final role = myProfile?['role'] as String? ?? 'caregiver';

    if (role == 'therapist') {
      // Therapist → list clients
      final links = await _client
          .from('therapist_client_link')
          .select('client_id')
          .eq('therapist_id', userId);

      final ids = (links as List).map((l) => l['client_id'] as String).toList();
      if (ids.isEmpty) return [];

      final profiles = await _client
          .from('profiles')
          .select('user_id, full_name, role, email, avatar_url')
          .inFilter('user_id', ids);

      return List<Map<String, dynamic>>.from(profiles);
    } else {
      // Caregiver → find linked therapist
      final links = await _client
          .from('therapist_client_link')
          .select('therapist_id')
          .eq('client_id', userId)
          .limit(1);

      if ((links as List).isEmpty) return [];

      final therapistId = links[0]['therapist_id'] as String;
      final profile = await _client
          .from('profiles')
          .select('user_id, full_name, role, email, avatar_url')
          .eq('user_id', therapistId)
          .maybeSingle();

      return profile != null ? [profile] : [];
    }
  }

  // ── Notification helper ───────────────────────────────────────────────

  Future<void> _notifyRecipient(String recipientId, String senderName) async {
    try {
      await _client.from('notifications').insert({
        'user_id': recipientId,
        'title': 'New Message',
        'body': 'New message from $senderName',
        'type': 'chat_message',
        'is_read': false,
      });
    } catch (_) {
      // Best-effort
    }
  }
}
