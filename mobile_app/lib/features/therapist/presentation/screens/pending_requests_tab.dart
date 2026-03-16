import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../caregiver/models/session_request.dart';
import '../../services/therapist_session_service.dart';
import 'session_response_screen.dart';

/// UCD033 – Pending Requests Tab
///
/// Displayed inside the Therapist Dashboard when the "Sessions" nav item
/// is selected.  Shows pending requests at the top with an optional
/// "All Requests" section below for history.
class PendingRequestsTab extends StatefulWidget {
  const PendingRequestsTab({super.key});

  @override
  State<PendingRequestsTab> createState() => _PendingRequestsTabState();
}

class _PendingRequestsTabState extends State<PendingRequestsTab> {
  final TherapistSessionService _service = TherapistSessionService();

  late Future<List<SessionRequest>> _pendingFuture;
  late Future<List<SessionRequest>> _allFuture;

  // ── Colours ────────────────────────────────────────────────────────────
  static const _primary = Color(0xFF1E40AF);

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  void _loadRequests() {
    _pendingFuture = _service.getPendingRequests();
    _allFuture = _service.getRequestsForTherapist();
  }

  Future<void> _refresh() async {
    setState(_loadRequests);
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: _primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.inbox, color: _primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Text('Session Requests',
                      style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87)),
                ],
              ),
            ),
          ),

          // ── Pending section ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text('Pending Requests',
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade800)),
            ),
          ),

          _buildRequestSection(_pendingFuture,
              emptyMessage: 'No pending requests 🎉'),

          // ── Divider ─────────────────────────────────────────────────────
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Divider(),
            ),
          ),

          // ── All requests section ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              child: Text('All Requests',
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700])),
            ),
          ),

          _buildRequestSection(_allFuture, emptyMessage: 'No requests yet.'),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ── Section builder ────────────────────────────────────────────────────

  Widget _buildRequestSection(
    Future<List<SessionRequest>> future, {
    required String emptyMessage,
  }) {
    return SliverToBoxAdapter(
      child: FutureBuilder<List<SessionRequest>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return _emptyState(
              Icons.error_outline,
              'Failed to load requests.\nPull to refresh.',
              Colors.red,
            );
          }

          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return _emptyState(
              Icons.inbox_outlined,
              emptyMessage,
              Colors.grey,
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: requests
                  .map((r) => _RequestCard(
                        request: r,
                        onTap: () => _openDetail(r),
                      ))
                  .toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 40, color: color.withValues(alpha: 0.4)),
          const SizedBox(height: 10),
          Text(text,
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────

  Future<void> _openDetail(SessionRequest request) async {
    final didChange = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SessionResponseScreen(request: request),
      ),
    );

    // Refresh list if the therapist accepted / declined
    if (didChange == true) {
      _refresh();
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _RequestCard — compact card for one session request
// ═════════════════════════════════════════════════════════════════════════════

class _RequestCard extends StatelessWidget {
  final SessionRequest request;
  final VoidCallback onTap;

  const _RequestCard({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // ── Avatar / icon ───────────────────────────────────────────
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_statusIcon, color: _statusColor, size: 26),
              ),

              const SizedBox(width: 14),

              // ── Info ────────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.requesterName ?? 'Caregiver',
                      style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${DateFormat('d MMM yyyy').format(request.preferredDate)}'
                      '  •  ${request.timeSlot.label}',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (request.reason.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        request.reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // ── Status badge ────────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request.status.label,
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _statusColor),
                ),
              ),

              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Color get _statusColor {
    switch (request.status) {
      case SessionRequestStatus.pending:
        return Colors.amber.shade700;
      case SessionRequestStatus.approved:
        return const Color(0xFF059669);
      case SessionRequestStatus.declined:
        return const Color(0xFFDC2626);
      case SessionRequestStatus.cancelled:
        return Colors.grey;
    }
  }

  IconData get _statusIcon {
    switch (request.status) {
      case SessionRequestStatus.pending:
        return Icons.hourglass_top;
      case SessionRequestStatus.approved:
        return Icons.check_circle;
      case SessionRequestStatus.declined:
        return Icons.cancel;
      case SessionRequestStatus.cancelled:
        return Icons.block;
    }
  }
}
