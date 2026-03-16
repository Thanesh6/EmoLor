import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/flagged_message.dart';
import '../services/moderation_service.dart';
import 'moderation_detail_screen.dart';

/// UCD035 – Moderation Queue
///
/// Shows a list of flagged / reported messages for the admin to review.
/// Tabs: Pending | Resolved.  Selecting a case opens [ModerationDetailScreen].
class ModerationQueueScreen extends StatefulWidget {
  const ModerationQueueScreen({super.key});

  @override
  State<ModerationQueueScreen> createState() => _ModerationQueueScreenState();
}

class _ModerationQueueScreenState extends State<ModerationQueueScreen>
    with SingleTickerProviderStateMixin {
  final ModerationService _service = ModerationService();
  late TabController _tabController;

  List<FlaggedMessage> _pending = [];
  List<FlaggedMessage> _resolved = [];
  bool _loadingPending = true;
  bool _loadingResolved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _resolved.isEmpty && !_loadingResolved) {
        _loadResolved();
      }
    });
    _loadPending();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPending() async {
    setState(() {
      _loadingPending = true;
      _error = null;
    });
    try {
      final flags = await _service.getFlags(status: FlagStatus.pending);
      if (!mounted) return;
      setState(() {
        _pending = flags;
        _loadingPending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load flagged messages';
        _loadingPending = false;
      });
    }
  }

  Future<void> _loadResolved() async {
    setState(() => _loadingResolved = true);
    try {
      final flags = await _service.getFlags(status: FlagStatus.resolved);
      if (!mounted) return;
      setState(() {
        _resolved = flags;
        _loadingResolved = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingResolved = false);
    }
  }

  void _openDetail(FlaggedMessage flag) async {
    final didResolve = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ModerationDetailScreen(flag: flag),
      ),
    );
    if (didResolve == true) {
      _loadPending();
      // Also refresh resolved if already loaded
      if (_resolved.isNotEmpty) _loadResolved();
    }
  }

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
                  Icon(Icons.shield_outlined,
                      color: Colors.orange[700], size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Moderation Queue',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  // Refresh
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    onPressed: () {
                      _loadPending();
                      if (_resolved.isNotEmpty) _loadResolved();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                        const Text('Pending'),
                        if (_pending.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_pending.length}',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Tab(text: 'Resolved'),
                ],
              ),
            ],
          ),
        ),

        // ── Tab views ───────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Pending tab
              _buildPendingTab(),
              // Resolved tab
              _buildResolvedTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Pending Tab ───────────────────────────────────────────────────────

  Widget _buildPendingTab() {
    if (_loadingPending) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text(_error!, style: GoogleFonts.poppins(color: Colors.red[400])),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadPending,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_pending.isEmpty) {
      return _buildEmptyState();
    }
    return RefreshIndicator(
      onRefresh: _loadPending,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _pending.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _FlagCard(
          flag: _pending[i],
          onTap: () => _openDetail(_pending[i]),
        ),
      ),
    );
  }

  // ── Resolved Tab ──────────────────────────────────────────────────────

  Widget _buildResolvedTab() {
    if (_loadingResolved) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_resolved.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No resolved cases yet',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadResolved,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _resolved.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _FlagCard(
          flag: _resolved[i],
          onTap: () => _openDetail(_resolved[i]),
        ),
      ),
    );
  }

  // ── Empty state (UCD035 alt-flow) ─────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user, size: 64, color: Colors.green[300]),
          const SizedBox(height: 16),
          Text(
            'No flagged content. All clear! 🎉',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.green[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'There are no pending reports to review.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Flag Card Widget ────────────────────────────────────────────────────

class _FlagCard extends StatelessWidget {
  final FlaggedMessage flag;
  final VoidCallback onTap;

  const _FlagCard({required this.flag, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy – h:mm a');

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: reason chip + status chip
              Row(
                children: [
                  _ReasonChip(reason: flag.reason),
                  const Spacer(),
                  if (flag.status == FlagStatus.resolved &&
                      flag.resolution != null)
                    _ResolutionChip(resolution: flag.resolution!),
                  if (flag.status == FlagStatus.pending)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Text(
                        'Pending',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Sender info
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF1E40AF).withValues(alpha: 0.1),
                    child: Text(
                      flag.senderName.isNotEmpty
                          ? flag.senderName[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          flag.senderName,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          flag.senderRole.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    dateFormat.format(flag.createdAt.toLocal()),
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Message preview (truncated)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  flag.messageContent.length > 120
                      ? '${flag.messageContent.substring(0, 120)}…'
                      : flag.messageContent,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[800],
                    height: 1.5,
                  ),
                ),
              ),

              // Reporter name (if user-reported)
              if (flag.reporterName != null && flag.reporterName!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        'Reported by ${flag.reporterName}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reason Chip ─────────────────────────────────────────────────────────

class _ReasonChip extends StatelessWidget {
  final FlagReason reason;
  const _ReasonChip({required this.reason});

  Color get _color {
    switch (reason) {
      case FlagReason.harassment:
        return Colors.red;
      case FlagReason.profanity:
        return Colors.deepOrange;
      case FlagReason.prohibitedKeywords:
        return Colors.orange;
      case FlagReason.spam:
        return Colors.amber;
      case FlagReason.inappropriateContent:
        return Colors.purple;
      case FlagReason.userReport:
        return Colors.blue;
      case FlagReason.other:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag, size: 14, color: _color),
          const SizedBox(width: 4),
          Text(
            reason.label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Resolution Chip ─────────────────────────────────────────────────────

class _ResolutionChip extends StatelessWidget {
  final FlagResolution resolution;
  const _ResolutionChip({required this.resolution});

  Color get _color {
    switch (resolution) {
      case FlagResolution.dismissed:
        return Colors.green;
      case FlagResolution.deleted:
        return Colors.orange;
      case FlagResolution.suspended:
        return Colors.red;
    }
  }

  IconData get _icon {
    switch (resolution) {
      case FlagResolution.dismissed:
        return Icons.check_circle_outline;
      case FlagResolution.deleted:
        return Icons.delete_outline;
      case FlagResolution.suspended:
        return Icons.block;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 14, color: _color),
          const SizedBox(width: 4),
          Text(
            resolution.label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}
