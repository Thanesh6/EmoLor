import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/supabase_service.dart';
import '../../models/chat_message.dart';
import '../../services/chat_service.dart';
import '../providers/conversation_provider.dart';
import 'conversation_view_screen.dart';

/// UCD031 – Conversation Thread List
///
/// Displays all conversation threads for the current user, each showing:
/// • Contact avatar & name
/// • Last message preview
/// • Timestamp of last activity
/// • Unread message badge count
///
/// Tapping a thread navigates to [ConversationViewScreen] (UCD031 Main Flow).
class ConversationListScreen extends ConsumerStatefulWidget {
  const ConversationListScreen({super.key});

  @override
  ConsumerState<ConversationListScreen> createState() =>
      _ConversationListScreenState();
}

class _ConversationListScreenState
    extends ConsumerState<ConversationListScreen> {
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _contactProfiles = [];

  String get _myUserId => SupabaseService.currentUserId ?? '';

  @override
  void initState() {
    super.initState();
    _loadContactProfiles();
  }

  /// Load profile details for contacts so we can show role information.
  Future<void> _loadContactProfiles() async {
    try {
      _contactProfiles = await _chatService.getLinkedContacts();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  /// Look up the role for a given user ID from cached contact profiles.
  String _getRoleForUser(String userId) {
    final contact = _contactProfiles.firstWhere(
      (c) => c['user_id'] == userId,
      orElse: () => <String, dynamic>{},
    );
    return (contact['role'] as String?) ?? '';
  }

  /// Navigate to the conversation view (UCD031 Main Flow step 1).
  void _openThread(Conversation conversation) {
    final contactName = conversation.otherParticipantName(_myUserId);
    final contactId = conversation.otherParticipantId(_myUserId);
    final contactRole = _getRoleForUser(contactId);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationViewScreen(
          conversation: conversation,
          contactName: contactName,
          contactRole: contactRole,
        ),
      ),
    );
  }

  /// Format a timestamp for the conversation list.
  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final local = dt.toLocal();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (_isSameDay(local, now)) return DateFormat('h:mm a').format(local);
    if (_isSameDay(local, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    if (diff.inDays < 7) return DateFormat('EEE').format(local);
    return DateFormat('MMM d').format(local);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(conversationListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            'Conversations',
            style:
                GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),

        // Body
        Expanded(
          child: conversationsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _buildErrorState(error),
            data: (conversations) => conversations.isEmpty
                ? _buildEmptyState()
                : _buildConversationList(conversations),
          ),
        ),
      ],
    );
  }

  // ── Error state ───────────────────────────────────────────────────────

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text(
              'Failed to load conversations',
              style: GoogleFonts.poppins(
                  color: Colors.red[700], fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(conversationListProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No conversations yet',
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            'Link with a therapist or client to start chatting.',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Conversation list ─────────────────────────────────────────────────

  Widget _buildConversationList(List<Conversation> conversations) {
    return RefreshIndicator(
      onRefresh: () => ref.read(conversationListProvider.notifier).refresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: conversations.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final convo = conversations[index];
          return _ConversationTile(
            conversation: convo,
            myUserId: _myUserId,
            contactRole: _getRoleForUser(convo.otherParticipantId(_myUserId)),
            formattedTime: _formatTimestamp(convo.lastMessageAt),
            onTap: () => _openThread(convo),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ─── Conversation Tile ─────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final String myUserId;
  final String contactRole;
  final String formattedTime;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.myUserId,
    required this.contactRole,
    required this.formattedTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = conversation.otherParticipantName(myUserId);
    final preview = conversation.lastMessagePreview;
    final hasUnread = conversation.hasUnread;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: contactRole == 'therapist'
                ? const Color(0xFF1E40AF)
                : const Color(0xFF6B21A8),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          // Unread badge
          if (hasUnread)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                child: Text(
                  conversation.unreadCount > 9
                      ? '9+'
                      : '${conversation.unreadCount}',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        name,
        style: GoogleFonts.poppins(
          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: preview != null
          ? Text(
              preview,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: hasUnread ? Colors.black87 : Colors.grey[600],
                fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : Text(
              contactRole == 'therapist' ? 'Therapist' : 'Caregiver',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
            ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formattedTime,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: hasUnread ? const Color(0xFF6B21A8) : Colors.grey[500],
              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          Icon(
            Icons.chevron_right,
            size: 20,
            color: Colors.grey[400],
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
