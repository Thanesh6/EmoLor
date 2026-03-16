import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/chat_message.dart';
import '../../services/chat_service.dart';

/// UCD031 – Conversation State Provider
///
/// Manages the state of the active conversation view:
/// • Message history (loaded from DB, updated via Realtime).
/// • Unread badge counts (per-conversation and total).
/// • Loading / error states.

// ── Conversation List Provider ─────────────────────────────────────────

/// Holds the list of conversation threads for the current user.
final conversationListProvider = StateNotifierProvider<ConversationListNotifier,
    AsyncValue<List<Conversation>>>(
  (ref) => ConversationListNotifier(ref),
);

class ConversationListNotifier
    extends StateNotifier<AsyncValue<List<Conversation>>> {
  final ChatService _chatService = ChatService();

  ConversationListNotifier(Ref ref) : super(const AsyncValue.loading()) {
    loadConversations();
  }

  Future<void> loadConversations() async {
    state = const AsyncValue.loading();
    try {
      final conversations = await _chatService.getMyConversations();
      state = AsyncValue.data(conversations);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Refresh after sending/receiving a message or marking as read.
  Future<void> refresh() async {
    try {
      final conversations = await _chatService.getMyConversations();
      state = AsyncValue.data(conversations);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Mark a specific conversation as read (unread = 0) locally
  /// and persist via ChatService.
  Future<void> markAsRead(String conversationId) async {
    await _chatService.markAsRead(conversationId);
    // Update local state
    state.whenData((conversations) {
      final updated = conversations.map((c) {
        if (c.id == conversationId) return c.copyWith(unreadCount: 0);
        return c;
      }).toList();
      state = AsyncValue.data(updated);
    });
  }
}

// ── Total Unread Count Provider ────────────────────────────────────────

/// Provides the total unread message count across all conversations.
/// Used for the dashboard badge.
final totalUnreadCountProvider = FutureProvider<int>((ref) async {
  final chatService = ChatService();
  return chatService.getTotalUnreadCount();
});

// ── Active Conversation Messages Provider ──────────────────────────────

/// Holds the messages + realtime state for the currently-viewed conversation.
final activeConversationProvider =
    StateNotifierProvider<ActiveConversationNotifier, ActiveConversationState>(
  (ref) => ActiveConversationNotifier(),
);

class ActiveConversationState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? errorMessage;
  final bool isSending;

  const ActiveConversationState({
    this.messages = const [],
    this.isLoading = false,
    this.errorMessage,
    this.isSending = false,
  });

  ActiveConversationState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? errorMessage,
    bool? isSending,
  }) {
    return ActiveConversationState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSending: isSending ?? this.isSending,
    );
  }
}

class ActiveConversationNotifier
    extends StateNotifier<ActiveConversationState> {
  final ChatService _chatService = ChatService();
  RealtimeChannel? _realtimeChannel;

  ActiveConversationNotifier() : super(const ActiveConversationState());

  /// Load message history for a conversation and subscribe to realtime.
  Future<void> openConversation(String conversationId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final messages = await _chatService.getMessages(conversationId);
      await _chatService.markAsRead(conversationId);

      // Subscribe to realtime
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = _chatService.subscribeToMessages(
        conversationId,
        _onNewMessage,
      );

      state = state.copyWith(messages: messages, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load history. Pull to refresh.',
      );
    }
  }

  void _onNewMessage(ChatMessage message) {
    // Avoid duplicates
    if (state.messages.any((m) => m.id == message.id)) return;
    state = state.copyWith(messages: [...state.messages, message]);
  }

  /// Append a sent message optimistically.
  void addMessage(ChatMessage message) {
    if (state.messages.any((m) => m.id == message.id)) return;
    state = state.copyWith(messages: [...state.messages, message]);
  }

  /// Close the active conversation and clean up realtime subscription.
  void closeConversation() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    state = const ActiveConversationState();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}
