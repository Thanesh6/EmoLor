import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../shared/models/scheduled_session.dart';
import '../../services/session_scheduling_service.dart';
import 'schedule_session_screen.dart';

/// UCD034 – Schedule Tab
///
/// A calendar-based view embedded in the therapist dashboard.
/// Shows a month calendar with dots on days that have sessions, and a
/// day-detail list below.  FAB opens the schedule-new-session form.
class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  final SessionSchedulingService _service = SessionSchedulingService();

  DateTime _focusedMonth = DateTime.now();
  late DateTime _selectedDay;
  Set<DateTime> _sessionDates = {};
  List<ScheduledSession> _daySessions = [];
  bool _loadingDay = false;

  static const _primary = Color(0xFF1E40AF);
  static const _accent = Color(0xFF059669);

  @override
  void initState() {
    super.initState();
    _selectedDay =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    _loadMonthMarkers();
    _loadDaySessions();
  }

  // ── Data ───────────────────────────────────────────────────────────────

  Future<void> _loadMonthMarkers() async {
    final start = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final end = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final dates =
        await _service.getSessionDates(rangeStart: start, rangeEnd: end);
    if (mounted) setState(() => _sessionDates = dates);
  }

  Future<void> _loadDaySessions() async {
    setState(() => _loadingDay = true);
    final sessions = await _service.getSessionsForDate(_selectedDay);
    if (mounted) {
      setState(() {
        _daySessions = sessions;
        _loadingDay = false;
      });
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      _loadMonthMarkers(),
      _loadDaySessions(),
    ]);
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: _primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Header ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.calendar_month,
                          color: _primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Text('Schedule',
                        style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E3A8A))),
                    const Spacer(),
                    // Schedule new session button
                    ElevatedButton.icon(
                      onPressed: _openScheduler,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text('New',
                          style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Month calendar ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildMonthCalendar(),
              ),
            ),

            // ── Day detail header ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Text(
                  _isToday(_selectedDay)
                      ? "Today's Sessions"
                      : DateFormat('EEEE, d MMMM').format(_selectedDay),
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _primary),
                ),
              ),
            ),

            // ── Day sessions list ───────────────────────────────────────
            if (_loadingDay)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_daySessions.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.event_available,
                          size: 44, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      Text('No sessions scheduled',
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: Colors.grey[500])),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _SessionCard(
                    session: _daySessions[i],
                    onCancel: () => _cancelSession(_daySessions[i]),
                  ),
                  childCount: _daySessions.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  // ── Simple month calendar ──────────────────────────────────────────────

  Widget _buildMonthCalendar() {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final startWeekday = firstDay.weekday % 7; // 0=Sun, 6=Sat

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _focusedMonth =
                        DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                  });
                  _loadMonthMarkers();
                },
              ),
              Text(
                DateFormat('MMMM yyyy').format(_focusedMonth),
                style: GoogleFonts.poppins(
                    fontSize: 17, fontWeight: FontWeight.w700),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _focusedMonth =
                        DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                  });
                  _loadMonthMarkers();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Weekday headers
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500])),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),

          // Day grid
          ...List.generate(6, (week) {
            return Row(
              children: List.generate(7, (col) {
                final dayIndex = week * 7 + col - startWeekday + 1;
                if (dayIndex < 1 || dayIndex > lastDay.day) {
                  return const Expanded(child: SizedBox(height: 42));
                }

                final date =
                    DateTime(_focusedMonth.year, _focusedMonth.month, dayIndex);
                final isSelected = _isSameDay(date, _selectedDay);
                final isToday = _isToday(date);
                final hasSession = _sessionDates.contains(date);

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedDay = date);
                      _loadDaySessions();
                    },
                    child: Container(
                      height: 42,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _primary
                            : isToday
                                ? _primary.withValues(alpha: 0.08)
                                : null,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayIndex',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight:
                                  isToday ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : isToday
                                      ? _primary
                                      : Colors.black87,
                            ),
                          ),
                          if (hasSession)
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : _accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> _openScheduler() async {
    final didCreate = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ScheduleSessionScreen()),
    );
    if (didCreate == true) _refresh();
  }

  Future<void> _cancelSession(ScheduledSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancel Session?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to cancel "${session.title}"? '
          'The caregiver will be notified.',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Keep',
                style: GoogleFonts.poppins(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Cancel Session',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.cancelSession(session);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Session cancelled.',
                style: GoogleFonts.poppins(fontSize: 13)),
            backgroundColor: Colors.grey[800],
            behavior: SnackBarBehavior.floating,
          ),
        );
        _refresh();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel session.',
                style: GoogleFonts.poppins(fontSize: 13)),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Date helpers ───────────────────────────────────────────────────────

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _SessionCard — compact card for one scheduled session
// ═════════════════════════════════════════════════════════════════════════════

class _SessionCard extends StatelessWidget {
  final ScheduledSession session;
  final VoidCallback onCancel;

  const _SessionCard({required this.session, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final isCancelled = session.status == ScheduledSessionStatus.cancelled;
    final isCompleted = session.status == ScheduledSessionStatus.completed;
    final timeStr = DateFormat('h:mm a').format(session.sessionDate);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Time badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCancelled
                    ? Colors.grey[200]
                    : isCompleted
                        ? Colors.green.withValues(alpha: 0.1)
                        : const Color(0xFF1E40AF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(timeStr,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isCancelled
                              ? Colors.grey
                              : const Color(0xFF1E40AF))),
                  if (session.timeSlot != null)
                    Text(session.timeSlot!.shortLabel,
                        style: GoogleFonts.poppins(
                            fontSize: 9, color: Colors.grey[500])),
                ],
              ),
            ),

            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isCancelled ? Colors.grey : Colors.black87,
                        decoration:
                            isCancelled ? TextDecoration.lineThrough : null,
                      )),
                  if (session.childName != null ||
                      session.caregiverName != null)
                    Text(
                      [
                        if (session.childName != null) session.childName!,
                        if (session.caregiverName != null)
                          session.caregiverName!,
                      ].join(' • '),
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey[600]),
                    ),
                  Text('${session.durationMinutes} min',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.grey[400])),
                ],
              ),
            ),

            // Status / actions
            if (session.status == ScheduledSessionStatus.scheduled)
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: Colors.red[300],
                tooltip: 'Cancel',
                onPressed: onCancel,
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  session.status.label,
                  style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _statusColor),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color get _statusColor {
    switch (session.status) {
      case ScheduledSessionStatus.scheduled:
        return const Color(0xFF1E40AF);
      case ScheduledSessionStatus.completed:
        return const Color(0xFF059669);
      case ScheduledSessionStatus.cancelled:
        return Colors.grey;
    }
  }
}
