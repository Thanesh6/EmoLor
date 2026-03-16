import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/engagement_analytics_service.dart';
import '../widgets/report_config_modal.dart';
import '../widgets/quick_export_modal.dart';
import '../models/analytics_filter_params.dart';
import '../widgets/filter_config_panel.dart';

/// UCD043 – View Activity Engagement Trends
///
/// Shared analytics screen showing bar chart (top activities),
/// line graph (daily usage), KPI cards (completion rate, avg time),
/// and interactive data points. Used by both Therapist and Caregiver.
class EngagementTrendsScreen extends StatefulWidget {
  final String childId;
  final String childName;

  const EngagementTrendsScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<EngagementTrendsScreen> createState() => _EngagementTrendsScreenState();
}

class _EngagementTrendsScreenState extends State<EngagementTrendsScreen> {
  final EngagementAnalyticsService _service = EngagementAnalyticsService();

  EngagementData? _data;
  bool _loading = true;
  int _selectedPeriodIndex = 0; // 0 = 7d, 1 = 30d, 2 = 90d
  int? _touchedBarIndex;
  AnalyticsFilterParams _filterParams = AnalyticsFilterParams.defaultParams;

  static const _periods = [
    _Period('Last 7 Days', 7),
    _Period('This Month', 30),
    _Period('Last 3 Months', 90),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final p = _periods[_selectedPeriodIndex];
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: p.days - 1));
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final data = await _service.getEngagement(
      childId: widget.childId,
      start: start,
      end: end,
      activityTypes: _filterParams.activityTypes.isNotEmpty
          ? _filterParams.activityTypes
          : null,
      statusFilter: _filterParams.statusFilter,
    );
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  void _onPeriodChanged(int index) {
    setState(() {
      _selectedPeriodIndex = index;
      _touchedBarIndex = null;
    });
    _load();
  }

  // ══════════════════════════════════════════════════════════════════════
  // ── Build ─────────────────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          '${widget.childName} – Engagement',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _filterParams.hasActiveFilters,
              label: Text('${_filterParams.activeFilterCount}'),
              child: const Icon(Icons.tune),
            ),
            tooltip: 'Filter & Parameters',
            onPressed: () async {
              final result = await FilterConfigPanel.show(
                context,
                current: _filterParams,
              );
              if (result != null) {
                setState(() => _filterParams = result);
                _load();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Current View',
            onPressed: _data == null || _data!.isEmpty
                ? null
                : () {
                    final p = _periods[_selectedPeriodIndex];
                    final now = DateTime.now();
                    final start = DateTime(now.year, now.month, now.day)
                        .subtract(Duration(days: p.days - 1));
                    final end =
                        DateTime(now.year, now.month, now.day, 23, 59, 59);
                    QuickExportModal.show(
                      context,
                      childName: widget.childName,
                      periodStart: start,
                      periodEnd: end,
                      engagementData: _data,
                      filterSummary: _filterParams.hasActiveFilters
                          ? _filterParams.filterSummary
                          : null,
                    );
                  },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More options',
            onSelected: (value) {
              if (value == 'advanced') {
                ReportConfigModal.show(
                  context,
                  childId: widget.childId,
                  childName: widget.childName,
                );
              } else if (value == 'refresh') {
                _load();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'advanced',
                child: ListTile(
                  leading: Icon(Icons.description_outlined),
                  title: Text('Advanced Export'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Refresh'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null || _data!.isEmpty
              ? _buildEmptyState()
              : _buildContent(),
    );
  }

  Widget _buildEmptyState() {
    final hasFilters = _filterParams.hasActiveFilters;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilters ? Icons.filter_list_off : Icons.analytics_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? 'No data found for this specific\nfilter combination.'
                : 'No activity was recorded\nduring this time.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[500]),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                setState(() => _filterParams = _filterParams.resetFilters());
                _load();
              },
              icon: const Icon(Icons.clear, size: 16),
              label: Text('Clear Filters',
                  style: GoogleFonts.poppins(fontSize: 13)),
            ),
          ],
          const SizedBox(height: 20),
          _buildPeriodSelector(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final d = _data!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPeriodSelector(),
          if (_filterParams.hasActiveFilters) ...[
            const SizedBox(height: 10),
            _buildActiveFiltersBanner(),
          ],
          const SizedBox(height: 20),

          // ── KPI cards ───────────────────────────────────────────
          _buildKpiRow(d),
          const SizedBox(height: 24),

          // ── Bar chart: Top Activities ───────────────────────────
          _sectionTitle('Top Activities', Icons.bar_chart),
          const SizedBox(height: 12),
          _buildTopActivitiesChart(d),
          const SizedBox(height: 24),

          // ── Line chart: Daily Usage Time ────────────────────────
          _sectionTitle('Daily Usage Time', Icons.show_chart),
          const SizedBox(height: 12),
          _buildDailyUsageChart(d),
          const SizedBox(height: 24),

          // ── Activity detail list ────────────────────────────────
          _sectionTitle('Recent Activity Details', Icons.list_alt),
          const SizedBox(height: 8),
          ..._buildActivityDetails(d),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // ── Period selector ───────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildPeriodSelector() {
    return Center(
      child: SegmentedButton<int>(
        segments: List.generate(
          _periods.length,
          (i) => ButtonSegment(
            value: i,
            label: Text(_periods[i].label,
                style: GoogleFonts.poppins(fontSize: 13)),
          ),
        ),
        selected: {_selectedPeriodIndex},
        onSelectionChanged: (s) => _onPeriodChanged(s.first),
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFiltersBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.indigo[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 16, color: Colors.indigo[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _filterParams.filterSummary,
              style:
                  GoogleFonts.poppins(fontSize: 11, color: Colors.indigo[700]),
            ),
          ),
          InkWell(
            onTap: () {
              setState(() => _filterParams = _filterParams.resetFilters());
              _load();
            },
            child: Text('Clear',
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.red[400])),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // ── KPI cards ─────────────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildKpiRow(EngagementData d) {
    return Row(
      children: [
        _kpiCard('Total Sessions', '${d.totalSessions}', Icons.play_circle,
            Colors.blue),
        const SizedBox(width: 10),
        _kpiCard('Completion', '${d.completionRate}%', Icons.check_circle,
            Colors.green),
        const SizedBox(width: 10),
        _kpiCard('Avg / Day', '${d.avgDailyMinutes} min', Icons.timer,
            Colors.orange),
        const SizedBox(width: 10),
        _kpiCard('Total Time', '${d.totalMinutes} min',
            Icons.access_time_filled, Colors.purple),
      ],
    );
  }

  Widget _kpiCard(
      String label, String value, IconData icon, MaterialColor color) {
    return Expanded(
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            children: [
              Icon(icon, color: color[600], size: 24),
              const SizedBox(height: 6),
              Text(
                value,
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // ── Bar chart – Top Activities ────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildTopActivitiesChart(EngagementData d) {
    final acts = d.topActivities;
    if (acts.isEmpty) {
      return _emptyChartCard('No activities in this period.');
    }

    final maxY =
        (acts.map((a) => a.count).reduce((a, b) => a > b ? a : b) * 1.25)
            .ceilToDouble();

    return SizedBox(
      height: 240,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
          child: BarChart(
            BarChartData(
              maxY: maxY,
              barTouchData: BarTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    _touchedBarIndex = response?.spot?.touchedBarGroupIndex;
                  });
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final act = acts[groupIndex];
                    return BarTooltipItem(
                      '${act.title}\n${act.count} sessions',
                      GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= acts.length) return const SizedBox();
                      final label = acts[i].title.length > 8
                          ? '${acts[i].title.substring(0, 7)}…'
                          : acts[i].title;
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(label,
                            style: GoogleFonts.poppins(
                                fontSize: 10, color: Colors.grey[700])),
                      );
                    },
                    reservedSize: 32,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) {
                      if (value == value.roundToDouble()) {
                        return Text('${value.toInt()}',
                            style: GoogleFonts.poppins(
                                fontSize: 10, color: Colors.grey[500]));
                      }
                      return const SizedBox();
                    },
                  ),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.grey[200]!,
                  strokeWidth: 1,
                ),
              ),
              barGroups: List.generate(acts.length, (i) {
                final isTouched = _touchedBarIndex == i;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: acts[i].count.toDouble(),
                      width: acts.length > 5 ? 14 : 22,
                      borderRadius: BorderRadius.circular(4),
                      color: isTouched
                          ? const Color(0xFF1E40AF)
                          : const Color(0xFF60A5FA),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // ── Line chart – Daily Usage Time ─────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildDailyUsageChart(EngagementData d) {
    final usage = d.dailyUsage;
    if (usage.isEmpty) {
      return _emptyChartCard('No daily data available.');
    }

    final maxMins = usage
        .map((u) => u.totalMinutes)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final maxY =
        (maxMins * 1.3).ceilToDouble().clamp(5.0, double.infinity).toDouble();

    return SizedBox(
      height: 220,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
          child: LineChart(
            LineChartData(
              maxY: maxY,
              minY: 0,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) {
                    return spots.map((spot) {
                      final u = usage[spot.spotIndex];
                      return LineTooltipItem(
                        '${DateFormat('MMM dd').format(u.date)}\n'
                        '${u.totalMinutes.toStringAsFixed(0)} min',
                        GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      );
                    }).toList();
                  },
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: _bottomInterval(usage.length),
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= usage.length) return const SizedBox();
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          DateFormat('dd').format(usage[i].date),
                          style: GoogleFonts.poppins(
                              fontSize: 10, color: Colors.grey[600]),
                        ),
                      );
                    },
                    reservedSize: 24,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) {
                      return Text('${value.toInt()}m',
                          style: GoogleFonts.poppins(
                              fontSize: 10, color: Colors.grey[500]));
                    },
                  ),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.grey[200]!,
                  strokeWidth: 1,
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(
                    usage.length,
                    (i) => FlSpot(i.toDouble(), usage[i].totalMinutes),
                  ),
                  isCurved: true,
                  preventCurveOverShooting: true,
                  color: const Color(0xFF1E40AF),
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: usage.length <= 31,
                    getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                      radius: 3,
                      color: Colors.white,
                      strokeWidth: 2,
                      strokeColor: const Color(0xFF1E40AF),
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF1E40AF).withValues(alpha: 0.08),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _bottomInterval(int count) {
    if (count <= 7) return 1;
    if (count <= 14) return 2;
    if (count <= 31) return 5;
    return 10;
  }

  // ══════════════════════════════════════════════════════════════════════
  // ── Recent activity detail list ───────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════

  List<Widget> _buildActivityDetails(EngagementData d) {
    final recent = d.dataPoints.reversed.take(20).toList();
    if (recent.isEmpty) {
      return [_emptyChartCard('No individual records.')];
    }

    return recent.map((pt) {
      final dateStr = DateFormat('MMM dd').format(pt.date);
      final statusColor =
          pt.status == 'completed' ? Colors.green[600]! : Colors.orange[600]!;
      return Card(
        elevation: 0,
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: statusColor.withValues(alpha: 0.1),
            child: Icon(
              pt.status == 'completed' ? Icons.check_circle : Icons.play_arrow,
              color: statusColor,
              size: 20,
            ),
          ),
          title: Text(
            pt.activityTitle,
            style:
                GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '$dateStr · ${pt.formattedDuration}'
            '${pt.score != null ? ' · Score: ${pt.score}' : ''}',
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${pt.completionPct}%',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor),
            ),
          ),
        ),
      );
    }).toList();
  }

  // ══════════════════════════════════════════════════════════════════════
  // ── Helpers ───────────────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════

  Widget _sectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1E40AF)),
        const SizedBox(width: 8),
        Text(text,
            style:
                GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _emptyChartCard(String message) {
    return Card(
      elevation: 0,
      color: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        height: 140,
        child: Center(
          child: Text(message,
              style:
                  GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
        ),
      ),
    );
  }
}

// ── Period helper ────────────────────────────────────────────────────────

class _Period {
  final String label;
  final int days;
  const _Period(this.label, this.days);
}
