import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/admin_service.dart';

/// UCD010 – Admin Dashboard Overview.
/// Queries the database for system-wide statistics and renders
/// data-visualisation widgets. Each widget handles its own error
/// state independently (alt-flow: "Data unavailable").
class AdminOverviewScreen extends StatefulWidget {
  const AdminOverviewScreen({super.key});

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  final AdminService _adminService = AdminService();

  bool _isLoading = true;
  Map<String, int?> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _adminService.getDashboardStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (_) {
      // Total failure — every metric will be null
      if (mounted) {
        setState(() {
          _stats = {};
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ── Header ──────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.dashboard, size: 28, color: Color(0xFF1E40AF)),
              const SizedBox(width: 10),
              Text('Dashboard Overview',
                  style: GoogleFonts.poppins(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const Spacer(),
              _RefreshChip(onTap: _loadStats),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'High-level system usage and health at a glance.',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 28),

          // ── Top stat cards (row 1) ──────────────────────────────
          _StatRow(children: [
            _StatCard(
              title: 'Total Registered Users',
              value: _stats['totalUsers'],
              icon: Icons.groups,
              color: const Color(0xFF1E40AF),
            ),
            _StatCard(
              title: 'Active Caregivers',
              value: _stats['activeCaregivers'],
              icon: Icons.family_restroom,
              color: const Color(0xFF0EA5E9),
            ),
            _StatCard(
              title: 'Active Therapists',
              value: _stats['activeTherapists'],
              icon: Icons.medical_services_outlined,
              color: const Color(0xFF8B5CF6),
            ),
          ]),
          const SizedBox(height: 16),

          // ── Bottom stat cards (row 2) ───────────────────────────
          _StatRow(children: [
            _StatCard(
              title: 'Active Children',
              value: _stats['activeChildren'],
              icon: Icons.child_care,
              color: const Color(0xFFFB923C),
            ),
            _StatCard(
              title: 'Deactivated Users',
              value: _stats['deactivatedUsers'],
              icon: Icons.person_off,
              color: const Color(0xFFEF4444),
            ),
            _StatCard(
              title: 'Recently Deactivated (7d)',
              value: _stats['recentlyDeactivated'],
              icon: Icons.history_toggle_off,
              color: const Color(0xFFD946EF),
            ),
          ]),
          const SizedBox(height: 32),

          // ── System Health section ───────────────────────────────
          Text('System Health',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _HealthCard(stats: _stats),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Reusable widgets
// ═══════════════════════════════════════════════════════════════════════

/// Arranges children evenly in a responsive row.
class _StatRow extends StatelessWidget {
  final List<Widget> children;
  const _StatRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // On narrow screens, stack vertically
        if (constraints.maxWidth < 600) {
          return Column(
            children: children
                .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: c,
                    ))
                .toList(),
          );
        }
        return Row(
          children: children
              .map((c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: c,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

/// Single metric card. value == null ⇒ "Data unavailable" (UCD010 alt-flow).
class _StatCard extends StatelessWidget {
  final String title;
  final int? value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = value != null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              color.withValues(alpha: 0.04),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
                if (!hasData)
                  Tooltip(
                    message: 'Error loading this metric',
                    child: Icon(Icons.warning_amber_rounded,
                        color: Colors.orange.shade400, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              hasData ? value.toString() : '—',
              style: GoogleFonts.poppins(
                fontSize: hasData ? 32 : 24,
                fontWeight: FontWeight.bold,
                color: hasData ? Colors.black87 : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasData ? title : 'Data unavailable',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: hasData ? Colors.grey.shade600 : Colors.orange.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (hasData)
              Text(
                title,
                style: GoogleFonts.poppins(
                    fontSize: 0, color: Colors.transparent), // For semantics
              ),
          ],
        ),
      ),
    );
  }
}

/// Green/amber/red health summary based on the metrics.
class _HealthCard extends StatelessWidget {
  final Map<String, int?> stats;
  const _HealthCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    // Determine how many metrics loaded successfully
    final totalMetrics = stats.length;
    final loadedMetrics = stats.values.where((v) => v != null).length;
    final allLoaded = totalMetrics > 0 && loadedMetrics == totalMetrics;
    final someLoaded = loadedMetrics > 0;

    final Color statusColor;
    final IconData statusIcon;
    final String statusText;
    final String statusDetail;

    if (allLoaded) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'All Systems Operational';
      statusDetail = 'All $totalMetrics metrics loaded successfully.';
    } else if (someLoaded) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning_amber_rounded;
      statusText = 'Partial Data Available';
      statusDetail =
          '$loadedMetrics of $totalMetrics metrics loaded. Some widgets show "Data unavailable".';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.error_outline;
      statusText = 'Error Loading Data';
      statusDetail =
          'Unable to retrieve system metrics. Check your connection and try again.';
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(statusIcon, color: statusColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(statusText,
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: statusColor)),
                  const SizedBox(height: 4),
                  Text(statusDetail,
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small refresh chip for the header.
class _RefreshChip extends StatelessWidget {
  final VoidCallback onTap;
  const _RefreshChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.refresh, size: 18),
      label: Text('Refresh', style: GoogleFonts.poppins(fontSize: 13)),
      onPressed: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
