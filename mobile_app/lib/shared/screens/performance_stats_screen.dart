import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/performance_stats_service.dart';
import '../widgets/report_config_modal.dart';
import '../widgets/quick_export_modal.dart';
import '../models/analytics_filter_params.dart';
import '../widgets/filter_config_panel.dart';

/// UCD044 – View Performance Statistics
///
/// Displays a radar chart of all skill categories, KPI summary cards,
/// and per-category detail bar charts. Includes a date-range selector
/// and graceful handling of insufficient data (<5 completed activities).
class PerformanceStatsScreen extends StatefulWidget {
  final String childId;
  final String childName;

  const PerformanceStatsScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<PerformanceStatsScreen> createState() => _PerformanceStatsScreenState();
}

class _PerformanceStatsScreenState extends State<PerformanceStatsScreen> {
  final PerformanceStatsService _service = PerformanceStatsService();

  PerformanceData? _data;
  bool _loading = true;
  int _periodIndex = 1; // 0 = 7d, 1 = 30d, 2 = 90d
  String? _selectedCategory;
  AnalyticsFilterParams _filterParams = AnalyticsFilterParams.defaultParams;

  static const _periods = [
    _Period('This Week', 7),
    _Period('Last Month', 30),
    _Period('Last 3 Months', 90),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final p = _periods[_periodIndex];
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: p.days - 1));
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final data = await _service.getPerformance(
      childId: widget.childId,
      start: start,
      end: end,
      category: _selectedCategory,
      activityTypes: _filterParams.activityTypes.isNotEmpty
          ? _filterParams.activityTypes
          : null,
      skillCategories: _filterParams.skillCategories.isNotEmpty
          ? _filterParams.skillCategories
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
    setState(() => _periodIndex = index);
    _load();
  }

  void _onCategoryTap(String category) {
    setState(() {
      _selectedCategory = _selectedCategory == category ? null : category;
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── Build ──────────────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          '${widget.childName} – Performance',
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
                    final p = _periods[_periodIndex];
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
                      performanceData: _data,
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
              ? _emptyState()
              : !_data!.hasSufficientData
                  ? _insufficientDataState()
                  : _content(),
    );
  }

  // ── Empty / insufficient states ──────────────────────────────────────

  Widget _emptyState() {
    if (_filterParams.hasActiveFilters) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list_off, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 14),
            Text(
              'No data matches your filters.',
              style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[500]),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting the filter criteria.',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400]),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _filterParams = _filterParams.resetFilters());
                _load();
              },
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Clear Filters'),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 14),
          Text(
            'No performance data yet.',
            style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[500]),
          ),
          const SizedBox(height: 6),
          Text(
            'Complete activities to start tracking skill mastery.',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _insufficientDataState() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.data_usage, size: 56, color: Colors.orange[200]),
              const SizedBox(height: 14),
              Text(
                'Not enough data yet',
                style: GoogleFonts.poppins(
                    fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete at least 5 activities to generate skill statistics.\n'
                '${_data!.totalCompleted}/5 activities completed so far.',
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: _data!.totalCompleted / 5,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange[300]!),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
          ),
        ),
      );

  // ── Active-filter banner ──────────────────────────────────────────────

  Widget _buildActiveFiltersBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 18, color: Colors.indigo.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _filterParams.filterSummary,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.indigo.shade700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() => _filterParams = _filterParams.resetFilters());
              _load();
            },
            child: Text(
              'Clear',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.indigo,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Main content ─────────────────────────────────────────────────────

  Widget _content() {
    final data = _data!;
    final catStats = _selectedCategory != null &&
            data.categoryStats.containsKey(_selectedCategory)
        ? data.categoryStats[_selectedCategory!]
        : null;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (_filterParams.hasActiveFilters) _buildActiveFiltersBanner(),
          _periodSelector(),
          const SizedBox(height: 20),
          _kpiRow(data),
          const SizedBox(height: 24),
          _sectionTitle('Skill Mastery Overview'),
          const SizedBox(height: 12),
          _radarCard(data),
          const SizedBox(height: 24),
          _sectionTitle('Skill Categories'),
          const SizedBox(height: 12),
          _categoryChips(data),
          if (catStats != null) ...[
            const SizedBox(height: 20),
            _categoryDetailCard(catStats),
            const SizedBox(height: 16),
            _categoryBarChart(catStats),
          ],
          const SizedBox(height: 24),
          _sectionTitle('Adaptive Difficulty'),
          const SizedBox(height: 12),
          _levelCard(data),
        ],
      ),
    );
  }

  // ── Period selector ──────────────────────────────────────────────────

  Widget _periodSelector() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<int>(
        segments: List.generate(
          _periods.length,
          (i) => ButtonSegment(value: i, label: Text(_periods[i].label)),
        ),
        selected: {_periodIndex},
        onSelectionChanged: (s) => _onPeriodChanged(s.first),
        style: SegmentedButton.styleFrom(
          textStyle: GoogleFonts.poppins(fontSize: 13),
        ),
      ),
    );
  }

  // ── KPI row ──────────────────────────────────────────────────────────

  Widget _kpiRow(PerformanceData data) {
    return Row(
      children: [
        _kpiCard(
          icon: Icons.gps_fixed,
          label: 'Accuracy',
          value: '${data.overallAccuracy}%',
          color: Colors.teal,
        ),
        const SizedBox(width: 10),
        _kpiCard(
          icon: Icons.timer_outlined,
          label: 'Avg Response',
          value: _formatResponseTime(data.overallResponseTimeMs),
          color: Colors.deepPurple,
        ),
        const SizedBox(width: 10),
        _kpiCard(
          icon: Icons.trending_up,
          label: 'Level',
          value: data.currentLevel.toString(),
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _kpiCard({
    required IconData icon,
    required String label,
    required String value,
    required MaterialColor color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color[400], size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  // ── Radar chart ──────────────────────────────────────────────────────

  Widget _radarCard(PerformanceData data) {
    final axes = data.radarAxes.where((a) => a.sessions > 0).toList();
    if (axes.length < 3) {
      return _infoCard(
        'Complete activities in at least 3 skill categories to display the radar chart.',
        Icons.radar,
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          SizedBox(
            height: 260,
            child: RadarChart(
              RadarChartData(
                radarShape: RadarShape.polygon,
                dataSets: [
                  RadarDataSet(
                    dataEntries: axes
                        .map((a) => RadarEntry(value: a.accuracy.toDouble()))
                        .toList(),
                    fillColor: Colors.indigo.withValues(alpha: 0.2),
                    borderColor: Colors.indigo,
                    borderWidth: 2,
                    entryRadius: 3,
                  ),
                ],
                radarBorderData:
                    const BorderSide(color: Color(0xFFE0E0E0), width: 1),
                tickBorderData:
                    const BorderSide(color: Color(0xFFEEEEEE), width: 1),
                gridBorderData:
                    const BorderSide(color: Color(0xFFE0E0E0), width: 1),
                tickCount: 4,
                ticksTextStyle:
                    GoogleFonts.poppins(fontSize: 9, color: Colors.grey[400]),
                titleTextStyle: GoogleFonts.poppins(
                    fontSize: 10, fontWeight: FontWeight.w500),
                getTitle: (i, _) => RadarChartTitle(
                  text: _shortCatLabel(axes[i].category),
                ),
                titlePositionPercentageOffset: 0.15,
                radarBackgroundColor: Colors.transparent,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Accuracy (%) per skill area',
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // ── Category chips ───────────────────────────────────────────────────

  Widget _categoryChips(PerformanceData data) {
    final cats = data.categoryStats.keys.toList()..sort();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: cats.map((cat) {
        final isSelected = _selectedCategory == cat;
        final cs = data.categoryStats[cat]!;
        return FilterChip(
          label: Text('$cat (${cs.totalSessions})'),
          selected: isSelected,
          onSelected: (_) => _onCategoryTap(cat),
          selectedColor: Colors.indigo[100],
          labelStyle: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? Colors.indigo[800] : Colors.grey[700],
          ),
          avatar: isSelected ? const Icon(Icons.check, size: 16) : null,
        );
      }).toList(),
    );
  }

  // ── Category detail card ─────────────────────────────────────────────

  Widget _categoryDetailCard(CategoryPerformance cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cs.category,
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              _miniMetric('Accuracy', '${cs.accuracyRate}%', Colors.teal),
              _miniMetric(
                  'Response', cs.responseTimeFormatted, Colors.deepPurple),
              _miniMetric('Level', '${cs.currentLevel}', Colors.orange),
              _miniMetric('Completed',
                  '${cs.completedSessions}/${cs.totalSessions}', Colors.blue),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: cs.completionRate / 100,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(
                cs.completionRate >= 80
                    ? Colors.green[400]!
                    : cs.completionRate >= 50
                        ? Colors.orange[400]!
                        : Colors.red[300]!,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${cs.completionRate.toStringAsFixed(0)}% completion',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMetric(String label, String value, MaterialColor color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color[600])),
          Text(label,
              style:
                  GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500])),
        ],
      ),
    );
  }

  // ── Category timeline bar chart ──────────────────────────────────────

  Widget _categoryBarChart(CategoryPerformance cs) {
    final completed =
        cs.timeline.where((p) => p.status == 'completed').toList();
    if (completed.isEmpty) {
      return _infoCard('No completed activities in this category yet.',
          Icons.bar_chart_outlined);
    }
    // Show last 10
    final recent = completed.length > 10
        ? completed.sublist(completed.length - 10)
        : completed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Accuracy',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, gIndex, rod, rIndex) {
                      final pt = recent[group.x];
                      return BarTooltipItem(
                        '${pt.activityTitle}\n${pt.accuracyPct}%',
                        GoogleFonts.poppins(fontSize: 11, color: Colors.white),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 25,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: GoogleFonts.poppins(
                            fontSize: 9, color: Colors.grey[500]),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        if (v.toInt() >= recent.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${recent[v.toInt()].date.day}/${recent[v.toInt()].date.month}',
                            style: GoogleFonts.poppins(
                                fontSize: 9, color: Colors.grey[500]),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: Colors.grey[200]!,
                    strokeWidth: 1,
                  ),
                ),
                barGroups: List.generate(recent.length, (i) {
                  final acc = recent[i].accuracyPct.toDouble();
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: acc > 0 ? acc : (recent[i].score?.toDouble() ?? 0),
                        width: 14,
                        color: acc >= 80
                            ? Colors.teal[400]
                            : acc >= 50
                                ? Colors.orange[400]
                                : Colors.red[300],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Level card ───────────────────────────────────────────────────────

  Widget _levelCard(PerformanceData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo[300]!, Colors.indigo[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '${data.currentLevel}',
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.levelLabel,
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Current adaptive difficulty based on recent performance',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  Widget _sectionTitle(String text) => Text(
        text,
        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
      );

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );

  Widget _infoCard(String message, IconData icon) => Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey[400], size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                style:
                    GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
              ),
            ),
          ],
        ),
      );

  String _formatResponseTime(int ms) {
    if (ms <= 0) return '—';
    if (ms < 1000) return '${ms}ms';
    return '${(ms / 1000).toStringAsFixed(1)}s';
  }

  String _shortCatLabel(String cat) {
    switch (cat) {
      case 'Emotion Recognition':
        return 'Emotion\nRecog.';
      case 'Social Cues':
        return 'Social\nCues';
      case 'Self-Regulation':
        return 'Self-\nRegulation';
      case 'Creative Expression':
        return 'Creative\nExpr.';
      case 'Cognitive Skills':
        return 'Cognitive\nSkills';
      default:
        return cat;
    }
  }
}

class _Period {
  final String label;
  final int days;
  const _Period(this.label, this.days);
}
