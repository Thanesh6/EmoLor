import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../shared/models/scheduled_session.dart';
import '../../services/session_scheduling_service.dart';

/// UCD034 – Schedule New Session Screen
///
/// Displays a calendar date-picker, time-slot chips, participant selector,
/// title & notes fields.  On confirm the service checks for slot conflicts
/// and creates the session entry.
class ScheduleSessionScreen extends StatefulWidget {
  /// When non-null the form is pre-populated from an approved session request.
  final DateTime? prefilledDate;
  final SessionTimeSlot? prefilledSlot;
  final String? prefilledCaregiverId;
  final String? prefilledChildProfileId;
  final String? prefilledTitle;
  final String? sessionRequestId;

  const ScheduleSessionScreen({
    super.key,
    this.prefilledDate,
    this.prefilledSlot,
    this.prefilledCaregiverId,
    this.prefilledChildProfileId,
    this.prefilledTitle,
    this.sessionRequestId,
  });

  @override
  State<ScheduleSessionScreen> createState() => _ScheduleSessionScreenState();
}

class _ScheduleSessionScreenState extends State<ScheduleSessionScreen> {
  final SessionSchedulingService _service = SessionSchedulingService();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  DateTime _selectedDate = DateTime.now();
  SessionTimeSlot? _selectedSlot;
  LinkedClient? _selectedClient;
  LinkedChild? _selectedChild;
  Set<SessionTimeSlot> _takenSlots = {};

  List<LinkedClient> _clients = [];
  bool _loadingClients = true;
  bool _loadingSlots = false;
  bool _isSubmitting = false;

  // ── Colours ────────────────────────────────────────────────────────────
  static const _primary = Color(0xFF1E40AF);
  static const _accent = Color(0xFF059669);

  @override
  void initState() {
    super.initState();
    _loadClients();

    // Apply prefilled values
    if (widget.prefilledDate != null) {
      _selectedDate = widget.prefilledDate!;
    }
    if (widget.prefilledSlot != null) {
      _selectedSlot = widget.prefilledSlot;
    }
    if (widget.prefilledTitle != null) {
      _titleController.text = widget.prefilledTitle!;
    }

    _loadTakenSlots();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────

  Future<void> _loadClients() async {
    final clients = await _service.getLinkedClients();
    if (!mounted) return;
    setState(() {
      _clients = clients;
      _loadingClients = false;

      // Auto-select prefilled caregiver
      if (widget.prefilledCaregiverId != null) {
        _selectedClient = clients.cast<LinkedClient?>().firstWhere(
              (c) => c?.caregiverId == widget.prefilledCaregiverId,
              orElse: () => null,
            );

        // Auto-select prefilled child
        if (_selectedClient != null && widget.prefilledChildProfileId != null) {
          _selectedChild =
              _selectedClient!.children.cast<LinkedChild?>().firstWhere(
                    (c) => c?.id == widget.prefilledChildProfileId,
                    orElse: () => null,
                  );
        }
      }
    });
  }

  Future<void> _loadTakenSlots() async {
    setState(() => _loadingSlots = true);
    final taken = await _service.getTakenSlots(_selectedDate);
    if (!mounted) return;
    setState(() {
      _takenSlots = taken;
      _loadingSlots = false;
      // Clear selected slot if it's now taken
      if (_selectedSlot != null && _takenSlots.contains(_selectedSlot)) {
        _selectedSlot = null;
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF),
      appBar: AppBar(
        title: Text('Schedule Session',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Date picker ───────────────────────────────────────────
              _sectionLabel('Select Date', Icons.calendar_today),
              const SizedBox(height: 12),
              _buildDatePicker(),

              const SizedBox(height: 28),

              // ── Time slot ─────────────────────────────────────────────
              _sectionLabel('Select Time Slot', Icons.access_time),
              const SizedBox(height: 12),
              _buildTimeSlotChips(),

              const SizedBox(height: 28),

              // ── Participant ────────────────────────────────────────────
              _sectionLabel('Participant', Icons.people),
              const SizedBox(height: 12),
              _buildParticipantPicker(),

              const SizedBox(height: 28),

              // ── Title ─────────────────────────────────────────────────
              _sectionLabel('Session Title', Icons.title),
              const SizedBox(height: 12),
              _buildTitleField(),

              const SizedBox(height: 20),

              // ── Notes ─────────────────────────────────────────────────
              _sectionLabel('Notes (optional)', Icons.notes),
              const SizedBox(height: 12),
              _buildNotesField(),

              const SizedBox(height: 32),

              // ── Submit ────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline, size: 22),
                  label: Text(
                    'Schedule Session',
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section label ──────────────────────────────────────────────────────

  Widget _sectionLabel(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _primary),
        const SizedBox(width: 8),
        Text(text,
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
      ],
    );
  }

  // ── Date picker ────────────────────────────────────────────────────────

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.calendar_month, color: _primary, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE').format(_selectedDate),
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey[500]),
                ),
                Text(
                  DateFormat('d MMMM yyyy').format(_selectedDate),
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.edit_calendar, color: _primary.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _loadTakenSlots();
    }
  }

  // ── Time-slot chips ────────────────────────────────────────────────────

  Widget _buildTimeSlotChips() {
    if (_loadingSlots) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: SessionTimeSlot.values.map((slot) {
        final isTaken = _takenSlots.contains(slot);
        final isSelected = _selectedSlot == slot;

        return ChoiceChip(
          label: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(slot.name[0].toUpperCase() + slot.name.substring(1),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isTaken
                        ? Colors.grey[400]
                        : isSelected
                            ? Colors.white
                            : _primary,
                  )),
              Text(slot.shortLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: isTaken
                        ? Colors.grey[400]
                        : isSelected
                            ? Colors.white70
                            : Colors.grey[600],
                  )),
            ],
          ),
          selected: isSelected,
          onSelected: isTaken
              ? null
              : (selected) {
                  setState(() => _selectedSlot = selected ? slot : null);
                },
          selectedColor: _primary,
          backgroundColor: isTaken ? Colors.grey[100] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isTaken
                  ? Colors.grey[300]!
                  : isSelected
                      ? _primary
                      : Colors.grey[300]!,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          showCheckmark: false,
        );
      }).toList(),
    );
  }

  // ── Participant picker ─────────────────────────────────────────────────

  Widget _buildParticipantPicker() {
    if (_loadingClients) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_clients.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No linked clients found. Link a caregiver first.',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.amber.shade800),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Caregiver dropdown
        DropdownButtonFormField<LinkedClient>(
          initialValue: _selectedClient,
          decoration: InputDecoration(
            labelText: 'Caregiver',
            labelStyle: GoogleFonts.poppins(fontSize: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primary, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.person, color: _primary),
          ),
          items: _clients
              .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c.caregiverName,
                        style: GoogleFonts.poppins(fontSize: 14)),
                  ))
              .toList(),
          onChanged: (client) {
            setState(() {
              _selectedClient = client;
              _selectedChild = null;
            });
          },
        ),

        // Child dropdown (only if caregiver has children)
        if (_selectedClient != null &&
            _selectedClient!.children.isNotEmpty) ...[
          const SizedBox(height: 14),
          DropdownButtonFormField<LinkedChild>(
            initialValue: _selectedChild,
            decoration: InputDecoration(
              labelText: 'Child',
              labelStyle: GoogleFonts.poppins(fontSize: 14),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _primary, width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.child_care, color: _primary),
            ),
            items: _selectedClient!.children
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(
                        c.age != null ? '${c.name} (age ${c.age})' : c.name,
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    ))
                .toList(),
            onChanged: (child) => setState(() => _selectedChild = child),
          ),
        ],
      ],
    );
  }

  // ── Title field ────────────────────────────────────────────────────────

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: InputDecoration(
        hintText: 'e.g. Therapy Session, Progress Review',
        hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      style: GoogleFonts.poppins(fontSize: 14),
      validator: (v) => (v == null || v.trim().isEmpty)
          ? 'Please enter a session title'
          : null,
    );
  }

  // ── Notes field ────────────────────────────────────────────────────────

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: 'Any additional notes or goals for this session…',
        hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      style: GoogleFonts.poppins(fontSize: 14),
    );
  }

  // ── Submit ─────────────────────────────────────────────────────────────

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSlot == null) {
      _showError('Please select a time slot.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _service.scheduleSession(
        date: _selectedDate,
        timeSlot: _selectedSlot!,
        title: _titleController.text.trim(),
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        caregiverId: _selectedClient?.caregiverId,
        childProfileId: _selectedChild?.id,
        sessionRequestId: widget.sessionRequestId,
      );

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
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle, color: _accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Session Scheduled!',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          content: Text(
            'The session has been added to your calendar. '
            '${_selectedClient != null ? 'A notification has been sent to ${_selectedClient!.caregiverName}.' : ''}',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // close dialog
                Navigator.of(context).pop(true); // return to list
              },
              child: Text('OK',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, color: _primary)),
            ),
          ],
        ),
      );
    } on SlotTakenException catch (e) {
      if (!mounted) return;
      _showError(e.message);
      // Refresh taken slots so chip turns grey
      _loadTakenSlots();
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to schedule session. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
