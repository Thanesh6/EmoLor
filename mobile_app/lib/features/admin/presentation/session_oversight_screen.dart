import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/scheduled_session.dart';
import '../services/session_oversight_service.dart';

/// UCD037 – Manage Scheduled Sessions (Admin)
///
/// Global list of sessions with search/filter, status tabs (Upcoming /
/// All), and the ability to force-cancel any session with a reason.
class SessionOversightScreen extends StatefulWidget {
  const SessionOversightScreen({super.key});

  @override
  State<SessionOversightScreen> createState() => _SessionOversightScreenState();
}

class _SessionOversightScreenState extends State<SessionOversightScreen>
    with SingleTickerProviderStateMixin {
  final SessionOversightService _service = SessionOversightService();
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  List<ScheduledSession> _upcoming = [];
  List<ScheduledSession> _all = [];
  bool _loadingUpcoming = true;
  bool _loadingAll = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _all.isEmpty && !_loadingAll) {
        _loadAll();
      }
    });
    _loadUpcoming();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────

  Future<void> _loadUpcoming() async {
    setState(() {
      _loadingUpcoming = true;
      _error = null;
    });
    try {
      final sessions = await _service.getSessions(
        includeAll: false,
        searchQuery: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
      );
      if (!mounted) return;
      setState(() {
        _upcoming = sessions;
        _loadingUpcoming = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load sessions';
        _loadingUpcoming = false;
      });
    }
  }

  Future<void> _loadAll() async {
    setState(() => _loadingAll = true);
    try {
      final sessions = await _service.getSessions(
        includeAll: true,
        searchQuery: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
      );
      if (!mounted) return;
      setState(() {
        _all = sessions;
        _loadingAll = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingAll = false);
    }
  }

  void _onSearch() {
    _loadUpcoming();
    if (_all.isNotEmpty) _loadAll();
  }

  // ── Force Cancel ──────────────────────────────────────────────────────

  Future<void> _showCancelDialog(ScheduledSession session) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Force Cancel Session',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session: ${session.title}',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Date: ${DateFormat('dd MMM yyyy').format(session.sessionDate)}'
              '${session.timeSlot != null ? '  •  ${session.timeSlot!.shortLabel}' : ''}',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Text(
              'This will notify the caregiver. '
              'Please provide a reason:',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g., Session cancelled by admin',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('A reason is required')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Force Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonCtrl.text.trim().isNotEmpty) {
      try {
        await _service.forceCancelSession(
          session: session,
          reason: reasonCtrl.text.trim(),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Session "${session.title}" cancelled. Notifications sent.'),
            backgroundColor: Colors.green[700],
          ),
        );
        _loadUpcoming();
        if (_all.isNotEmpty) _loadAll();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel session: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
    reasonCtrl.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_month,
                      color: Colors.indigo[600], size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Session Oversight',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    onPressed: () {
                      _loadUpcoming();
                      if (_all.isNotEmpty) _loadAll();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Search bar ────────────────────────────────────
              TextField(
                controller: _searchCtrl,
                onSubmitted: (_) => _onSearch(),
                decoration: InputDecoration(
                  hintText: 'Search by caregiver, child, or title…',
                  hintStyle: GoogleFonts.poppins(fontSize: 14),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearch();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // ── Tabs ──────────────────────────────────────────
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF1E40AF),
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: const Color(0xFF1E40AF),
                indicatorWeight: 3,
                labelStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Upcoming'),
                        if (_upcoming.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _Badge(count: _upcoming.length),
                        ],
                      ],
                    ),
                  ),
                  const Tab(text: 'All Sessions'),
                ],
              ),
            ],
          ),
        ),

        // ── Body ────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildList(_upcoming, _loadingUpcoming, isUpcoming: true),
              _buildList(_all, _loadingAll, isUpcoming: false),
            ],
          ),
        ),
      ],
    );
  }

  // ── List builder ──────────────────────────────────────────────────────

  Widget _buildList(
    List<ScheduledSession> sessions,
    bool loading, {
    required bool isUpcoming,
  }) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && isUpcoming) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text(_error!, style: GoogleFonts.poppins(color: Colors.red[600])),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadUpcoming,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              isUpcoming
                  ? 'No active sessions found for these criteria.'
                  : 'No sessions found.',
              style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: isUpcoming ? _loadUpcoming : _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sessions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _SessionCard(
          session: sessions[i],
          onCancel: sessions[i].status == ScheduledSessionStatus.scheduled
              ? () => _showCancelDialog(sessions[i])
              : null,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Private Widgets ─────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1E40AF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final ScheduledSession session;
  final VoidCallback? onCancel;

  const _SessionCard({required this.session, this.onCancel});

  Color _statusColor() {
    switch (session.status) {
      case ScheduledSessionStatus.scheduled:
        return Colors.blue[600]!;
      case ScheduledSessionStatus.completed:
        return Colors.green[600]!;
      case ScheduledSessionStatus.cancelled:
        return Colors.red[600]!;
    }
  }

  IconData _statusIcon() {
    switch (session.status) {
      case ScheduledSessionStatus.scheduled:
        return Icons.schedule;
      case ScheduledSessionStatus.completed:
        return Icons.check_circle_outline;
      case ScheduledSessionStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, dd MMM yyyy').format(session.sessionDate);
    final timeStr = session.timeSlot?.shortLabel ?? '';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: title + status chip ──────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(), size: 14, color: _statusColor()),
                      const SizedBox(width: 4),
                      Text(
                        session.status.label,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Date & time ──────────────────────────────────────
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  dateStr,
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.grey[700]),
                ),
                if (timeStr.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    timeStr,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
                const SizedBox(width: 12),
                Icon(Icons.timer_outlined, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${session.durationMinutes} min',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Participants ─────────────────────────────────────
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (session.caregiverName != null)
                  _ParticipantChip(
                    icon: Icons.person_outline,
                    label: session.caregiverName!,
                    color: Colors.teal,
                  ),
                if (session.childName != null)
                  _ParticipantChip(
                    icon: Icons.child_care,
                    label: session.childName!,
                    color: Colors.orange,
                  ),
              ],
            ),

            // ── Goals ────────────────────────────────────────────
            if (session.goals.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: session.goals
                    .take(3)
                    .map(
                      (g) => Chip(
                        label:
                            Text(g, style: GoogleFonts.poppins(fontSize: 11)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.purple[50],
                      ),
                    )
                    .toList(),
              ),
            ],

            // ── Force Cancel button ──────────────────────────────
            if (onCancel != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: Icon(Icons.block, size: 16, color: Colors.red[600]),
                  label: Text(
                    'Force Cancel',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[600],
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ParticipantChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final MaterialColor color;

  const _ParticipantChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color[400]),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: color[700]),
        ),
      ],
    );
  }
}
