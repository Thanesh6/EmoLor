import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/flagged_message.dart';
import '../services/moderation_service.dart';

/// UCD035 – Moderation Detail / Case Review
///
/// The admin selects a flagged case from the queue and lands here.
/// Shows:
///   • Flag metadata (reason, reporter, timestamp)
///   • The offending message in context (surrounding messages)
///   • Three resolution actions: Dismiss, Delete Message, Suspend User
///   • Confirmation dialog before executing any action
class ModerationDetailScreen extends StatefulWidget {
  final FlaggedMessage flag;

  const ModerationDetailScreen({super.key, required this.flag});

  @override
  State<ModerationDetailScreen> createState() => _ModerationDetailScreenState();
}

class _ModerationDetailScreenState extends State<ModerationDetailScreen> {
  final ModerationService _service = ModerationService();

  List<Map<String, dynamic>> _contextMessages = [];
  bool _loadingContext = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    final msgs = await _service.getMessageContext(
      conversationId: widget.flag.conversationId,
      messageId: widget.flag.messageId,
    );
    if (!mounted) return;
    setState(() {
      _contextMessages = msgs;
      _loadingContext = false;
    });
  }

  // ── Action handlers ───────────────────────────────────────────────────

  Future<void> _dismiss() async {
    final confirmed = await _confirmAction(
      title: 'Dismiss Flag?',
      body:
          'This will mark the report as a false alarm. The message will remain visible.',
      confirmLabel: 'Dismiss',
      confirmColor: Colors.green,
    );
    if (confirmed != true) return;
    setState(() => _processing = true);
    try {
      await _service.dismissFlag(widget.flag.id);
      if (!mounted) return;
      _showSnackBar('Flag dismissed', Colors.green);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      _showSnackBar('Failed to dismiss: $e', Colors.red);
    }
  }

  Future<void> _deleteMessage() async {
    final confirmed = await _confirmAction(
      title: 'Delete Message?',
      body:
          'The message content will be removed from chat and the sender will be notified.',
      confirmLabel: 'Delete Message',
      confirmColor: Colors.orange,
    );
    if (confirmed != true) return;
    setState(() => _processing = true);
    try {
      await _service.deleteMessage(widget.flag);
      if (!mounted) return;
      _showSnackBar('Message deleted', Colors.orange);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      _showSnackBar('Failed to delete: $e', Colors.red);
    }
  }

  Future<void> _suspendUser() async {
    final confirmed = await _confirmAction(
      title: 'Suspend User?',
      body:
          'This will deactivate "${widget.flag.senderName}"\'s account and delete the offending message. The user will be unable to log in.',
      confirmLabel: 'Suspend User',
      confirmColor: Colors.red,
    );
    if (confirmed != true) return;
    setState(() => _processing = true);
    try {
      await _service.suspendUser(widget.flag);
      if (!mounted) return;
      _showSnackBar('User suspended', Colors.red);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      _showSnackBar('Failed to suspend: $e', Colors.red);
    }
  }

  Future<bool?> _confirmAction({
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(body, style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel,
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy – h:mm a');
    final flag = widget.flag;
    final isResolved = flag.status == FlagStatus.resolved;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Case Review',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0.5,
      ),
      body: _processing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Status banner ─────────────────────────────────
                  if (isResolved) _buildResolvedBanner(flag, dateFormat),

                  // ── Flag info card ────────────────────────────────
                  _buildInfoCard(flag, dateFormat),
                  const SizedBox(height: 20),

                  // ── Offending message ─────────────────────────────
                  _buildFlaggedMessageCard(flag, dateFormat),
                  const SizedBox(height: 20),

                  // ── Message context ───────────────────────────────
                  _buildContextSection(flag, dateFormat),
                  const SizedBox(height: 28),

                  // ── Action buttons ────────────────────────────────
                  if (!isResolved) _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  // ── Resolved Banner ───────────────────────────────────────────────────

  Widget _buildResolvedBanner(FlaggedMessage flag, DateFormat fmt) {
    final color = flag.resolution == FlagResolution.dismissed
        ? Colors.green
        : flag.resolution == FlagResolution.suspended
            ? Colors.red
            : Colors.orange;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Resolved: ${flag.resolution?.label ?? 'Unknown'}'
                '${flag.resolvedAt != null ? ' on ${fmt.format(flag.resolvedAt!.toLocal())}' : ''}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Info Card ─────────────────────────────────────────────────────────

  Widget _buildInfoCard(FlaggedMessage flag, DateFormat fmt) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Flag Details',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 14),
            _infoRow('Reason', flag.reason.label),
            _infoRow('Flagged At', fmt.format(flag.createdAt.toLocal())),
            _infoRow('Sender', '${flag.senderName} (${flag.senderRole})'),
            if (flag.reporterName != null && flag.reporterName!.isNotEmpty)
              _infoRow('Reported By', flag.reporterName!),
            if (flag.details != null && flag.details!.isNotEmpty)
              _infoRow('Details', flag.details!),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: const Color(0xFF1E293B))),
          ),
        ],
      ),
    );
  }

  // ── Flagged message card ──────────────────────────────────────────────

  Widget _buildFlaggedMessageCard(FlaggedMessage flag, DateFormat fmt) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag, color: Colors.red[400], size: 20),
                const SizedBox(width: 8),
                Text('Flagged Message',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.red[800])),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.red[100],
                  child: Text(
                    flag.senderName.isNotEmpty
                        ? flag.senderName[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                        fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(flag.senderName,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                Text(
                  fmt.format(flag.messageSentAt.toLocal()),
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Text(
                flag.messageContent,
                style: GoogleFonts.poppins(fontSize: 14, height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Context section ───────────────────────────────────────────────────

  Widget _buildContextSection(FlaggedMessage flag, DateFormat fmt) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Conversation Context',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 14),
            if (_loadingContext)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_contextMessages.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No surrounding messages available',
                    style: GoogleFonts.poppins(color: Colors.grey[500]),
                  ),
                ),
              )
            else
              ..._contextMessages.map((m) {
                final isFlagged = m['id'] == flag.messageId;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isFlagged ? Colors.red[50] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: isFlagged
                        ? Border.all(color: Colors.red[300]!, width: 1.5)
                        : Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            (m['sender_name'] as String?) ?? 'Unknown',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: isFlagged
                                  ? Colors.red[700]
                                  : Colors.grey[700],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            m['created_at'] != null
                                ? DateFormat('h:mm a').format(
                                    DateTime.parse(m['created_at'] as String)
                                        .toLocal())
                                : '',
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: Colors.grey[500]),
                          ),
                          if (isFlagged) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.flag, size: 14, color: Colors.red[400]),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (m['content'] as String?) ?? '',
                        style: GoogleFonts.poppins(fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ── Action Buttons ────────────────────────────────────────────────────

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Resolution Actions',
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 14),
        Row(
          children: [
            // Dismiss
            Expanded(
              child: _ActionButton(
                icon: Icons.check_circle_outline,
                label: 'Dismiss\n(False Alarm)',
                color: Colors.green,
                onPressed: _dismiss,
              ),
            ),
            const SizedBox(width: 12),

            // Delete Message
            Expanded(
              child: _ActionButton(
                icon: Icons.delete_outline,
                label: 'Delete\nMessage',
                color: Colors.orange,
                onPressed: _deleteMessage,
              ),
            ),
            const SizedBox(width: 12),

            // Suspend User
            Expanded(
              child: _ActionButton(
                icon: Icons.block,
                label: 'Suspend\nUser',
                color: Colors.red,
                onPressed: _suspendUser,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Action Button Widget ────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: color,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
