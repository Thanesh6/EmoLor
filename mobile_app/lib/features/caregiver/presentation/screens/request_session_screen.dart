import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/session_request.dart';
import '../../services/session_request_service.dart';

/// UCD028 – Request Session screen.
///
/// Shows a form (Preferred Date, Time Slot, Reason/Topic) and submits a
/// session request to the caregiver's linked therapist.
/// If no therapist is linked, displays an error and redirects to
/// Link Account.
class RequestSessionScreen extends StatefulWidget {
  const RequestSessionScreen({super.key});

  @override
  State<RequestSessionScreen> createState() => _RequestSessionScreenState();
}

class _RequestSessionScreenState extends State<RequestSessionScreen> {
  final SessionRequestService _service = SessionRequestService();

  // State
  bool _isCheckingLink = true;
  bool _isSending = false;
  LinkedTherapistInfo? _therapist;

  // Form
  final _formKey = GlobalKey<FormState>();
  DateTime? _preferredDate;
  TimeSlot _timeSlot = TimeSlot.morning;
  final _reasonCtrl = TextEditingController();

  // For child selection (optional)
  String? _childName;

  @override
  void initState() {
    super.initState();
    _checkTherapistLink();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  // ── Check therapist link ──────────────────────────────────────────────

  Future<void> _checkTherapistLink() async {
    final info = await _service.getLinkedTherapist();
    if (!mounted) return;

    if (info == null) {
      // Alternative flow: not linked
      _showNotLinkedDialog();
      return;
    }

    setState(() {
      _therapist = info;
      _isCheckingLink = false;
    });
  }

  void _showNotLinkedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange[700], size: 28),
            const SizedBox(width: 10),
            Text('No Therapist Linked',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'You must be linked to a therapist to request a session.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (mounted) context.pop(); // go back
            },
            child:
                Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B21A8)),
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/link-account');
            },
            child: Text('Link Therapist',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Date picker ───────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _preferredDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6B21A8),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _preferredDate = picked);
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_preferredDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a preferred date.',
              style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      await _service.createRequest(
        therapistId: _therapist!.id,
        preferredDate: _preferredDate!,
        timeSlot: _timeSlot,
        reason: _reasonCtrl.text.trim(),
        childName: _childName,
      );
      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Failed to send request: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.check_circle, color: Colors.green[600], size: 48),
            ),
            const SizedBox(height: 16),
            Text('Request Sent!',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 22)),
          ],
        ),
        content: Text(
          'Your session request has been sent to '
          '${_therapist?.name ?? 'your therapist'}. '
          'You will be notified once they respond.',
          style: GoogleFonts.poppins(fontSize: 14),
          textAlign: TextAlign.center,
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B21A8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                if (mounted) context.pop();
              },
              child: Text('Done',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Request Session',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _isCheckingLink
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Therapist card ──
                    _buildTherapistCard(),
                    const SizedBox(height: 28),

                    // ── Preferred Date ──
                    _sectionLabel('Preferred Date'),
                    const SizedBox(height: 8),
                    _buildDatePicker(),
                    const SizedBox(height: 24),

                    // ── Time Slot ──
                    _sectionLabel('Time Slot'),
                    const SizedBox(height: 8),
                    _buildTimeSlotSelector(),
                    const SizedBox(height: 24),

                    // ── Reason / Topic ──
                    _sectionLabel('Reason / Topic'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _reasonCtrl,
                      style: GoogleFonts.poppins(fontSize: 14),
                      maxLines: 4,
                      decoration: _inputDecoration(
                        hint: 'What would you like to discuss? '
                            'e.g. Emotion regulation strategies, '
                            'progress review…',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please describe the purpose of the session'
                          : null,
                    ),
                    const SizedBox(height: 32),

                    // ── Submit button ──
                    ElevatedButton.icon(
                      onPressed: _isSending ? null : _submit,
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, size: 20),
                      label: Text(
                        _isSending ? 'Sending…' : 'Send Request',
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B21A8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── My Requests list (below the form) ──
                    _buildMyRequestsList(),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Therapist info card ───────────────────────────────────────────────

  Widget _buildTherapistCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6B21A8), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B21A8).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            backgroundImage: _therapist?.avatarUrl != null
                ? NetworkImage(_therapist!.avatarUrl!)
                : null,
            child: _therapist?.avatarUrl == null
                ? const Icon(Icons.person, color: Colors.white, size: 30)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Therapist',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.white70)),
                Text(_therapist?.name ?? 'Therapist',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                if (_therapist?.email != null)
                  Text(_therapist!.email!,
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.white60)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text('Linked',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Date picker widget ────────────────────────────────────────────────

  Widget _buildDatePicker() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 22, color: Colors.purple[700]),
            const SizedBox(width: 12),
            Text(
              _preferredDate != null
                  ? DateFormat('EEEE, MMM d, yyyy').format(_preferredDate!)
                  : 'Tap to select a date',
              style: GoogleFonts.poppins(
                fontSize: 15,
                color:
                    _preferredDate != null ? Colors.black87 : Colors.grey[500],
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_drop_down, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }

  // ── Time slot selector ────────────────────────────────────────────────

  Widget _buildTimeSlotSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: TimeSlot.values.map((slot) {
        final isSelected = _timeSlot == slot;
        return ChoiceChip(
          label: Text(
            slot.label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.grey[800],
            ),
          ),
          selected: isSelected,
          selectedColor: const Color(0xFF6B21A8),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelected ? const Color(0xFF6B21A8) : Colors.grey[300]!,
            ),
          ),
          onSelected: (_) => setState(() => _timeSlot = slot),
        );
      }).toList(),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(text,
        style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700]));
  }

  // ── Input decoration helper ───────────────────────────────────────────

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400]),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!)),
    );
  }

  // ── My Requests list ──────────────────────────────────────────────────

  Widget _buildMyRequestsList() {
    return FutureBuilder<List<SessionRequest>>(
      future: _service.getMyRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final requests = snapshot.data ?? [];
        if (requests.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 40),
            Text('My Requests',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...requests.map((req) => _RequestTile(request: req)),
          ],
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ─── Request tile ───────────────────────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════

class _RequestTile extends StatelessWidget {
  final SessionRequest request;
  const _RequestTile({required this.request});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _statusColor(request.status),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMM d, yyyy').format(request.preferredDate),
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${request.timeSlot.label}  •  ${request.reason}',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _statusBadge(request.status),
        ],
      ),
    );
  }

  Color _statusColor(SessionRequestStatus s) {
    switch (s) {
      case SessionRequestStatus.pending:
        return Colors.orange;
      case SessionRequestStatus.approved:
        return Colors.green;
      case SessionRequestStatus.declined:
        return Colors.red;
      case SessionRequestStatus.cancelled:
        return Colors.grey;
    }
  }

  Widget _statusBadge(SessionRequestStatus s) {
    final color = _statusColor(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        s.label,
        style: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
