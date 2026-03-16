import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../caregiver/models/session_request.dart';
import '../../services/therapist_session_service.dart';

/// UCD033 – Session Request Detail & Response Screen
///
/// Displays the full details of a pending session request and lets the
/// therapist Accept or Decline (with optional reason).
class SessionResponseScreen extends StatefulWidget {
  final SessionRequest request;

  const SessionResponseScreen({super.key, required this.request});

  @override
  State<SessionResponseScreen> createState() => _SessionResponseScreenState();
}

class _SessionResponseScreenState extends State<SessionResponseScreen> {
  final TherapistSessionService _service = TherapistSessionService();
  bool _isProcessing = false;

  // ── Colours ────────────────────────────────────────────────────────────
  static const _primary = Color(0xFF1E40AF);
  static const _accept = Color(0xFF059669);
  static const _decline = Color(0xFFDC2626);

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(req.preferredDate);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF),
      appBar: AppBar(
        title: Text('Session Request',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // ── Status banner ─────────────────────────────────────────────
            _buildStatusBanner(req),

            const SizedBox(height: 24),

            // ── Details card ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.event_note,
                            color: _primary, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Session Details',
                                style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87)),
                            Text('Review and respond',
                                style: GoogleFonts.poppins(
                                    fontSize: 13, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 20),

                  // ── Requester ───────────────────────────────────────────
                  _detailRow(
                    Icons.person,
                    'Requester',
                    req.requesterName ?? 'Caregiver',
                    Colors.indigo,
                  ),

                  // ── Child Name (if present) ─────────────────────────────
                  if (req.childName != null && req.childName!.isNotEmpty)
                    _detailRow(
                      Icons.child_care,
                      'Child',
                      req.childName!,
                      Colors.teal,
                    ),

                  // ── Date ────────────────────────────────────────────────
                  _detailRow(
                    Icons.calendar_today,
                    'Date',
                    dateStr,
                    Colors.blue,
                  ),

                  // ── Time Slot ───────────────────────────────────────────
                  _detailRow(
                    Icons.access_time,
                    'Time Slot',
                    req.timeSlot.label,
                    Colors.deepPurple,
                  ),

                  // ── Reason ──────────────────────────────────────────────
                  _detailRow(
                    Icons.description,
                    'Reason',
                    req.reason,
                    Colors.orange,
                  ),

                  // ── Submitted ───────────────────────────────────────────
                  _detailRow(
                    Icons.schedule,
                    'Submitted',
                    DateFormat('d MMM yyyy, h:mm a').format(req.createdAt),
                    Colors.grey,
                  ),

                  // ── Decline Reason (for already-declined) ───────────────
                  if (req.status == SessionRequestStatus.declined &&
                      req.declineReason != null &&
                      req.declineReason!.isNotEmpty)
                    _detailRow(
                      Icons.info_outline,
                      'Decline Reason',
                      req.declineReason!,
                      _decline,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Action buttons (only for pending) ─────────────────────────
            if (req.status == SessionRequestStatus.pending) ...[
              // Accept button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _handleAccept,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline, size: 22),
                  label: Text(
                    'Accept Session',
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accept,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Decline button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: _isProcessing ? null : _showDeclineDialog,
                  icon: const Icon(Icons.close, size: 22),
                  label: Text(
                    'Decline',
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _decline,
                    side: const BorderSide(color: _decline, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Status banner ──────────────────────────────────────────────────────

  Widget _buildStatusBanner(SessionRequest req) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (req.status) {
      case SessionRequestStatus.pending:
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade800;
        icon = Icons.hourglass_top;
        label = 'Awaiting Your Response';
        break;
      case SessionRequestStatus.approved:
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        icon = Icons.check_circle;
        label = 'Session Scheduled';
        break;
      case SessionRequestStatus.declined:
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        icon = Icons.cancel;
        label = 'Declined';
        break;
      case SessionRequestStatus.cancelled:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
        icon = Icons.block;
        label = 'Cancelled by Requester';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 22),
          const SizedBox(width: 12),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }

  // ── Detail row widget ──────────────────────────────────────────────────

  Widget _detailRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500])),
                const SizedBox(height: 2),
                Text(value,
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Accept handler ─────────────────────────────────────────────────────

  Future<void> _handleAccept() async {
    setState(() => _isProcessing = true);

    try {
      await _service.acceptRequest(widget.request);

      if (!mounted) return;

      // Show success dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accept.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle, color: _accept),
              ),
              const SizedBox(width: 12),
              Text('Session Confirmed',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            ],
          ),
          content: Text(
            'The session has been scheduled and the caregiver has been notified.',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // close dialog
                Navigator.of(context).pop(true); // return to list with refresh
              },
              child: Text('OK',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, color: _primary)),
            ),
          ],
        ),
      );
    } on SessionConflictException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(e.message);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Failed to accept session. Please try again.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Decline dialog ─────────────────────────────────────────────────────

  Future<void> _showDeclineDialog() async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _decline.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close, color: _decline),
            ),
            const SizedBox(width: 12),
            Text('Decline Session',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to decline this session request?',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Reason (optional) — e.g. Time conflict',
                hintStyle:
                    GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400]),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _primary, width: 1.5),
                ),
              ),
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _decline,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Decline',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      final reason = reasonController.text.trim();
      await _service.declineRequest(
        widget.request,
        reason: reason.isNotEmpty ? reason : null,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Session declined. Caregiver notified.',
                  style: GoogleFonts.poppins(fontSize: 13)),
            ],
          ),
          backgroundColor: Colors.grey[800],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pop(true); // return to list with refresh
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Failed to decline session. Please try again.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Error helper ───────────────────────────────────────────────────────

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: _decline,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
