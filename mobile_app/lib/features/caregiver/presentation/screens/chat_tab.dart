import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../../models/chat_message.dart';
import '../../services/chat_service.dart';
import '../../services/media_download_service.dart';
import 'media_preview_screen.dart';

/// UCD029 – Add Message / Feedback
///
/// Two-phase widget:
///   Phase 1  → Contact picker (list linked contacts).
///   Phase 2  → Active chat view with real-time messages.
///
/// Used as a tab inside both the Caregiver and Therapist dashboards.
class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final ChatService _chatService = ChatService();

  // Phase state
  bool _isLoadingContacts = true;
  List<Map<String, dynamic>> _contacts = [];
  String? _errorMessage;

  // Active chat state
  Conversation? _activeConversation;
  Map<String, dynamic>? _activeContact;
  List<ChatMessage> _messages = [];
  bool _isLoadingMessages = false;
  bool _isSending = false;
  bool _isUploading = false;
  PlatformFile? _pendingFile;

  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  RealtimeChannel? _realtimeChannel;

  String get _myUserId => SupabaseService.currentUserId ?? '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────

  Future<void> _loadContacts() async {
    setState(() {
      _isLoadingContacts = true;
      _errorMessage = null;
    });
    try {
      _contacts = await _chatService.getLinkedContacts();
    } catch (e) {
      _errorMessage = 'Failed to load contacts: $e';
    }
    if (mounted) setState(() => _isLoadingContacts = false);
  }

  Future<void> _openChat(Map<String, dynamic> contact) async {
    setState(() {
      _activeContact = contact;
      _isLoadingMessages = true;
    });

    try {
      // Get my name
      String myName = 'Me';
      try {
        final me = await SupabaseService.client
            .from('profiles')
            .select('full_name')
            .eq('user_id', _myUserId)
            .maybeSingle();
        myName = (me?['full_name'] as String?) ?? 'Me';
      } catch (_) {}

      final contactId = contact['user_id'] as String;
      final contactName = (contact['full_name'] as String?) ?? 'Contact';

      final convo = await _chatService.getOrCreateConversation(
        userAId: _myUserId,
        userAName: myName,
        userBId: contactId,
        userBName: contactName,
      );

      _messages = await _chatService.getMessages(convo.id);
      await _chatService.markAsRead(convo.id);

      // Subscribe to real-time updates
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = _chatService.subscribeToMessages(
        convo.id,
        _onNewMessage,
      );

      if (mounted) {
        setState(() {
          _activeConversation = convo;
          _isLoadingMessages = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMessages = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to open chat: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onNewMessage(ChatMessage message) {
    // Avoid duplicates (sender already added optimistically)
    if (_messages.any((m) => m.id == message.id)) return;
    if (mounted) {
      setState(() => _messages.add(message));
      _scrollToBottom();
      // Auto-mark as read
      if (message.senderId != _myUserId) {
        _chatService.markAsRead(_activeConversation!.id);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Send message ──────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _activeConversation == null) return;

    _msgController.clear();
    setState(() => _isSending = true);

    try {
      final recipientId = _activeConversation!.otherParticipantId(_myUserId);
      final sent = await _chatService.sendMessage(
        conversationId: _activeConversation!.id,
        recipientId: recipientId,
        content: text,
      );

      // Add optimistically (real-time might also deliver it)
      if (!_messages.any((m) => m.id == sent.id)) {
        setState(() => _messages.add(sent));
      }
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _isSending = false);
  }

  // ── UCD030 – Pick & send media ───────────────────────────────────────

  Future<void> _pickAttachment() async {
    if (_activeConversation == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ChatService.allowedExtensions,
      withData: false,
      withReadStream: false,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    // Validate immediately
    try {
      _chatService.validateFile(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', ''),
                style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Show preview and confirm
    setState(() => _pendingFile = file);
  }

  void _cancelPendingFile() {
    setState(() => _pendingFile = null);
  }

  Future<void> _sendPendingMedia() async {
    if (_pendingFile == null || _activeConversation == null) return;

    final file = _pendingFile!;
    setState(() {
      _isUploading = true;
      _pendingFile = null;
    });

    try {
      final recipientId = _activeConversation!.otherParticipantId(_myUserId);
      final sent = await _chatService.sendMediaMessage(
        conversationId: _activeConversation!.id,
        recipientId: recipientId,
        file: file,
        caption: _msgController.text.trim().isNotEmpty
            ? _msgController.text.trim()
            : null,
      );
      _msgController.clear();

      if (!_messages.any((m) => m.id == sent.id)) {
        setState(() => _messages.add(sent));
      }
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to send media: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _isUploading = false);
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _goBackToContacts() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    setState(() {
      _activeConversation = null;
      _activeContact = null;
      _messages = [];
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Phase 2: Active chat
    if (_activeConversation != null || _isLoadingMessages) {
      return _buildChatView();
    }
    // Phase 1: Contact list
    return _buildContactList();
  }

  // ════════════════════════════════════════════════════════════════════════
  // Phase 1 – Contact List
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildContactList() {
    if (_isLoadingContacts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 12),
              Text(_errorMessage!,
                  style: GoogleFonts.poppins(color: Colors.red[700]),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loadContacts,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No linked contacts yet.',
              style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              'Link with a therapist or client to start chatting.',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text('Conversations',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _contacts.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final c = _contacts[index];
              final name = (c['full_name'] as String?) ?? 'Contact';
              final role = (c['role'] as String?) ?? '';
              final avatar = c['avatar_url'] as String?;
              return ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: role == 'therapist'
                      ? const Color(0xFF1E40AF)
                      : const Color(0xFF6B21A8),
                  backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                  child: avatar == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        )
                      : null,
                ),
                title: Text(name,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  role == 'therapist' ? 'Therapist' : 'Caregiver',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.grey[600]),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () => _openChat(c),
              );
            },
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // Phase 2 – Active Chat View
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildChatView() {
    final contactName = (_activeContact?['full_name'] as String?) ?? 'Contact';
    final contactRole = (_activeContact?['role'] as String?) ?? '';

    return Column(
      children: [
        // ── Chat header ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBackToContacts,
              ),
              CircleAvatar(
                radius: 20,
                backgroundColor: contactRole == 'therapist'
                    ? const Color(0xFF1E40AF)
                    : const Color(0xFF6B21A8),
                child: Text(
                  contactName.isNotEmpty ? contactName[0].toUpperCase() : '?',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contactName,
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    Text(
                      contactRole == 'therapist' ? 'Therapist' : 'Caregiver',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              // Secure indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outlined,
                        size: 14, color: Colors.green[700]),
                    const SizedBox(width: 4),
                    Text('Secure',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Messages ──────────────────────────────────────────────────
        Expanded(
          child: _isLoadingMessages
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_outlined,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'No messages yet.\nStart the conversation!',
                            style: GoogleFonts.poppins(
                                color: Colors.grey[500], fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMe = msg.senderId == _myUserId;
                        final showDateSep = index == 0 ||
                            !_isSameDay(
                              _messages[index - 1].createdAt,
                              msg.createdAt,
                            );
                        return Column(
                          children: [
                            if (showDateSep) _dateSeparator(msg.createdAt),
                            _MessageBubble(message: msg, isMe: isMe),
                          ],
                        );
                      },
                    ),
        ),

        // ── Input bar ─────────────────────────────────────────────────
        if (_pendingFile != null) _buildMediaPreviewBar(),
        if (_isUploading) _buildUploadingIndicator(),
        _buildInputBar(),
      ],
    );
  }

  Widget _dateSeparator(DateTime date) {
    final label = _isToday(date)
        ? 'Today'
        : _isYesterday(date)
            ? 'Yesterday'
            : DateFormat('MMM d, yyyy').format(date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style:
                  GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isToday(DateTime d) => _isSameDay(d, DateTime.now());

  bool _isYesterday(DateTime d) =>
      _isSameDay(d, DateTime.now().subtract(const Duration(days: 1)));

  // ── Media preview bar (UCD030 step 5) ─────────────────────────────────

  Widget _buildMediaPreviewBar() {
    final file = _pendingFile!;
    final isImage = _chatService.isImageExtension(file.extension);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          // Thumbnail / icon
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 56,
              height: 56,
              color: Colors.grey[200],
              child: isImage && file.path != null
                  ? Image.file(
                      File(file.path!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.image, size: 28, color: Colors.grey[500]),
                    )
                  : Icon(Icons.insert_drive_file,
                      size: 28, color: Colors.blue[600]),
            ),
          ),
          const SizedBox(width: 12),
          // File info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  file.name,
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatFileSize(file.size),
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // Cancel
          IconButton(
            icon: Icon(Icons.close, color: Colors.grey[600], size: 20),
            tooltip: 'Cancel',
            onPressed: _cancelPendingFile,
          ),
          // Send
          IconButton(
            icon: const Icon(Icons.send_rounded,
                color: Color(0xFF6B21A8), size: 24),
            tooltip: 'Send file',
            onPressed: _sendPendingMedia,
          ),
        ],
      ),
    );
  }

  Widget _buildUploadingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[50],
      child: Row(
        children: [
          const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Text('Uploading media\u2026',
              style:
                  GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600])),
        ],
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Message type selector (popup for clinical note / feedback)
            PopupMenuButton<MessageType>(
              icon: Icon(Icons.add_circle_outline,
                  color: Colors.grey[600], size: 26),
              tooltip: 'Message type',
              onSelected: (type) {
                // Pre-fill a tag to make it visually clear
                if (type == MessageType.clinicalNote) {
                  _msgController.text = '[Clinical Note] ';
                  _msgController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _msgController.text.length),
                  );
                } else if (type == MessageType.feedback) {
                  _msgController.text = '[Feedback] ';
                  _msgController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _msgController.text.length),
                  );
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: MessageType.clinicalNote,
                  child: Row(
                    children: [
                      Icon(Icons.medical_information,
                          size: 20, color: Colors.blue[700]),
                      const SizedBox(width: 10),
                      Text('Clinical Note',
                          style: GoogleFonts.poppins(fontSize: 14)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: MessageType.feedback,
                  child: Row(
                    children: [
                      Icon(Icons.feedback_outlined,
                          size: 20, color: Colors.orange[700]),
                      const SizedBox(width: 10),
                      Text('Behavioral Feedback',
                          style: GoogleFonts.poppins(fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            // UCD030 – Attachment (paperclip) icon
            IconButton(
              icon: Icon(Icons.attach_file, color: Colors.grey[600], size: 24),
              tooltip: 'Attach file',
              onPressed: _isUploading ? null : _pickAttachment,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _msgController,
                style: GoogleFonts.poppins(fontSize: 15),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  hintStyle: GoogleFonts.poppins(
                      fontSize: 15, color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button — disabled when empty
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _msgController,
              builder: (context, value, child) {
                final canSend = value.text.trim().isNotEmpty && !_isSending;
                return IconButton(
                  icon: _isSending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.send_rounded,
                          color: canSend
                              ? const Color(0xFF6B21A8)
                              : Colors.grey[400]),
                  onPressed: canSend ? _sendMessage : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ─── Message bubble widget ─────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

class _MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  final MediaDownloadService _downloadService = MediaDownloadService();
  bool _isDownloading = false;

  ChatMessage get message => widget.message;
  bool get isMe => widget.isMe;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('h:mm a').format(message.createdAt.toLocal());
    final isClinical = message.messageType == MessageType.clinicalNote;
    final isFeedback = message.messageType == MessageType.feedback;
    final isMedia = message.messageType == MessageType.media;
    final isSpecial = isClinical || isFeedback;
    final isImage = message.mediaType == 'image';
    final isDocument = message.mediaType == 'document';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Message type label for clinical / feedback
            if (isSpecial)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isClinical
                          ? Icons.medical_information
                          : Icons.feedback_outlined,
                      size: 14,
                      color: isClinical ? Colors.blue[700] : Colors.orange[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      message.messageType.label,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color:
                            isClinical ? Colors.blue[700] : Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ),

            // Bubble
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMedia && isImage ? 4 : 14,
                vertical: isMedia && isImage ? 4 : 10,
              ),
              decoration: BoxDecoration(
                color: isMe
                    ? const Color(0xFF6B21A8)
                    : isSpecial
                        ? (isClinical ? Colors.blue[50] : Colors.orange[50])
                        : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                  bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                ),
                border: isSpecial && !isMe
                    ? Border.all(
                        color: isClinical
                            ? Colors.blue[200]!
                            : Colors.orange[200]!,
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender name (only for incoming messages)
                  if (!isMe)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: 2,
                        left: isMedia && isImage ? 10 : 0,
                        top: isMedia && isImage ? 4 : 0,
                      ),
                      child: Text(
                        message.senderName,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),

                  // UCD030 / UCD032 – Image attachment with download overlay
                  if (isMedia && isImage && message.mediaUrl != null)
                    GestureDetector(
                      onTap: () => _openMediaPreview(context),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                  maxHeight: 220, maxWidth: 260),
                              child: Image.network(
                                message.mediaUrl!,
                                fit: BoxFit.cover,
                                loadingBuilder: (_, child, progress) {
                                  if (progress == null) return child;
                                  return SizedBox(
                                    height: 140,
                                    width: 200,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: progress.expectedTotalBytes !=
                                                null
                                            ? progress.cumulativeBytesLoaded /
                                                progress.expectedTotalBytes!
                                            : null,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (_, __, ___) => Container(
                                  height: 100,
                                  width: 200,
                                  color: Colors.grey[300],
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image,
                                          color: Colors.grey[600]),
                                      const SizedBox(height: 4),
                                      Text('Image unavailable',
                                          style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: Colors.grey[600])),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // UCD032 – Download overlay icon
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: GestureDetector(
                              onTap: () => _quickDownload(isImage: true),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: _isDownloading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.download_rounded,
                                        size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // UCD030 / UCD032 – Document attachment
                  if (isMedia && isDocument && message.mediaUrl != null)
                    GestureDetector(
                      onTap: () => _openMediaPreview(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: isMe
                              ? null
                              : Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.insert_drive_file,
                              size: 28,
                              color: isMe ? Colors.white : Colors.blue[600],
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message.fileName ?? 'Document',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          isMe ? Colors.white : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (message.fileSizeBytes != null)
                                    Text(
                                      _formatSize(message.fileSizeBytes!),
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: isMe
                                            ? Colors.white70
                                            : Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.download_rounded,
                              size: 20,
                              color: isMe ? Colors.white70 : Colors.grey[500],
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Text content (skip for pure image media with no caption)
                  if (!(isMedia &&
                      isImage &&
                      message.content == message.fileName))
                    Padding(
                      padding: EdgeInsets.only(
                        top: isMedia && isImage ? 6 : 0,
                        left: isMedia && isImage ? 10 : 0,
                      ),
                      child: Text(
                        message.content,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: isMe ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),

                  const SizedBox(height: 4),
                  Padding(
                    padding: EdgeInsets.only(
                      left: isMedia && isImage ? 10 : 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: isMe ? Colors.white60 : Colors.grey[500],
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message.isRead ? Icons.done_all : Icons.done,
                            size: 14,
                            color:
                                message.isRead ? Colors.white : Colors.white60,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// UCD032 – Open full-screen media preview with download option.
  void _openMediaPreview(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaPreviewScreen(message: message),
      ),
    );
  }

  /// UCD032 – Quick download directly from in-bubble icon.
  Future<void> _quickDownload({required bool isImage}) async {
    if (_isDownloading || message.mediaUrl == null) return;
    setState(() => _isDownloading = true);

    final result = await _downloadService.downloadMedia(
      url: message.mediaUrl!,
      fileName: message.fileName ?? 'emolor_media',
      isImage: isImage,
    );

    if (!mounted) return;
    setState(() => _isDownloading = false);

    switch (result.status) {
      case DownloadStatus.success:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Download complete',
                    style: GoogleFonts.poppins(fontSize: 13)),
              ],
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      case DownloadStatus.permissionDenied:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permission required to save files.',
                style: GoogleFonts.poppins(fontSize: 13)),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
      case DownloadStatus.fileUnavailable:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File is no longer available.',
                style: GoogleFonts.poppins(fontSize: 13)),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
      case DownloadStatus.error:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Download failed.',
                style: GoogleFonts.poppins(fontSize: 13)),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
