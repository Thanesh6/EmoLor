import 'package:flutter/material.dart' hide Badge;
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/emotion_service.dart';
import '../../../../features/child/domain/models/emotion.dart';
import '../../../../features/child/models/completion_record.dart';
import '../../services/goal_service.dart';
import '../../services/progress_dashboard_service.dart';
import '../widgets/new_goal_dialog.dart';

/// UCD023 — View Progress Dashboard
///
/// Displays a visual summary of the child's emotion logs, activity
/// completion, weekly trends, and earned badges. Data is loaded from
/// local SharedPreferences via [ProgressDashboardService].
class ProgressDashboardScreen extends StatefulWidget {
  const ProgressDashboardScreen({super.key});

  @override
  State<ProgressDashboardScreen> createState() =>
      _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen> {
  final _service = ProgressDashboardService();
  late Future<ProgressData> _dataFuture;

  // Emotion palette (loaded once for colour lookups)
  List<Emotion> _emotions = EmotionService.defaultEmotions;

  // Goals (loaded separately so they can refresh independently)
  List<PerformanceGoal> _goals = [];

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadAll();
  }

  Future<ProgressData> _loadAll() async {
    // Load emotion palette for colour mapping
    await _loadEmotionPalette();
    await _loadGoals();
    return _service.loadProgress();
  }

  Future<void> _loadGoals() async {
    try {
      _goals = await GoalService.getAllGoals();
    } catch (_) {
      _goals = [];
    }
  }

  Future<void> _loadEmotionPalette() async {
    try {
      final loaded = await EmotionService.loadEmotionsStatic();
      if (loaded.isNotEmpty) _emotions = loaded;
    } catch (_) {}
  }

  void _retry() {
    setState(() {
      _dataFuture = _loadAll();
    });
  }

  Future<void> _openNewGoalDialog() async {
    final saved = await NewGoalDialog.show(context);
    if (saved == true) {
      await _loadGoals();
      setState(() {});
    }
  }

  Future<void> _deleteGoal(String goalId) async {
    await GoalService.deleteGoal(goalId);
    await _loadGoals();
    setState(() {});
  }

  // ── Helpers ──────────────────────────────────────────────────────

  TextStyle _poppins({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = Colors.black87,
  }) {
    return GoogleFonts.poppins(
        fontSize: size, fontWeight: weight, color: color);
  }

  Color _colorForEmotion(String emotionId) {
    final match = _emotions.where((e) => e.id == emotionId);
    if (match.isNotEmpty) return match.first.color;
    // Fallback colours
    switch (emotionId) {
      case 'happy':
        return const Color(0xFFFFE66D);
      case 'sad':
        return const Color(0xFF74B9FF);
      case 'calm':
        return const Color(0xFF7ED957);
      case 'angry':
        return const Color(0xFFFF6B6B);
      case 'scared':
        return const Color(0xFFBB6BD9);
      default:
        return Colors.grey;
    }
  }

  String _emojiForEmotion(String emotionId) {
    final match = _emotions.where((e) => e.id == emotionId);
    if (match.isNotEmpty) return match.first.emoji;
    switch (emotionId) {
      case 'happy':
        return '😊';
      case 'sad':
        return '😢';
      case 'calm':
        return '😌';
      case 'angry':
        return '😠';
      case 'scared':
        return '😨';
      default:
        return '🙂';
    }
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProgressData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }
        if (snapshot.hasError) {
          return _buildError();
        }
        final data = snapshot.data!;
        if (data.isEmpty) {
          return _buildEmpty();
        }
        return _buildDashboard(data);
      },
    );
  }

  // ── States ───────────────────────────────────────────────────────

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFF6B21A8)),
          SizedBox(height: 16),
          Text('Loading progress…'),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Could not load progress',
            style: _poppins(size: 18, weight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Please check your connection and try again.',
            style: _poppins(size: 14, color: Colors.grey[600]!),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B21A8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎮', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'No activities yet',
            style: _poppins(size: 20, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Start playing to see progress here!',
            style: _poppins(size: 15, color: Colors.grey[600]!),
          ),
        ],
      ),
    );
  }

  // ── Main dashboard ──────────────────────────────────────────────

  Widget _buildDashboard(ProgressData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Progress Dashboard',
            style: _poppins(
              size: 26,
              weight: FontWeight.w700,
              color: const Color(0xFF6B21A8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Weekly overview of your child\'s learning journey',
            style: _poppins(size: 14, color: Colors.grey[600]!),
          ),
          const SizedBox(height: 28),

          // Summary stats row
          _buildSummaryRow(data),
          const SizedBox(height: 28),

          // Mood Trends chart
          _buildSection(
            title: 'Mood Trends (This Week)',
            icon: Icons.insights,
            child: _buildMoodChart(data.weeklyMoods),
          ),
          const SizedBox(height: 24),

          // Activity Completion
          _buildSection(
            title: 'Activity Completion',
            icon: Icons.emoji_events,
            child: _buildActivityStats(data),
          ),
          const SizedBox(height: 24),

          // Active Goals (UCD024)
          _buildGoalsSection(),
          const SizedBox(height: 24),

          // Badges
          _buildSection(
            title: 'Earned Badges',
            icon: Icons.workspace_premium,
            child: _buildBadgeGrid(data.earnedBadges),
          ),

          if (data.recentCompletions.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSection(
              title: 'Recent Activities',
              icon: Icons.history,
              child: _buildRecentActivities(data.recentCompletions),
            ),
          ],
        ],
      ),
    );
  }

  // ── Summary row ─────────────────────────────────────────────────

  Widget _buildSummaryRow(ProgressData data) {
    final activeDays =
        data.weeklyMoods.where((d) => d.entries.isNotEmpty).length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final cards = [
          _summaryCard('⭐', 'Total Stars', '${data.totalStars}', Colors.orange),
          _summaryCard(
            '🎮',
            'Activities',
            '${data.activityStats.totalCompleted}',
            Colors.blue,
          ),
          _summaryCard(
            '🏅',
            'Badges',
            '${data.earnedBadges.length}',
            Colors.purple,
          ),
          _summaryCard(
            '📅',
            'Active Days',
            '$activeDays / 7',
            Colors.green,
          ),
        ];

        if (isWide) {
          return Row(
            children: cards
                .map((c) => Expanded(
                        child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: c,
                    )))
                .toList(),
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map((c) => SizedBox(
                    width: (constraints.maxWidth - 12) / 2,
                    child: c,
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _summaryCard(String emoji, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text(value, style: _poppins(size: 24, weight: FontWeight.w700)),
          Text(label, style: _poppins(size: 13, color: Colors.grey[600]!)),
        ],
      ),
    );
  }

  // ── Section wrapper ─────────────────────────────────────────────

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF6B21A8), size: 22),
              const SizedBox(width: 10),
              Text(title, style: _poppins(size: 18, weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  // ── Mood bar chart ──────────────────────────────────────────────

  Widget _buildMoodChart(List<DailyMood> week) {
    final hasAnyMoods = week.any((d) => d.entries.isNotEmpty);
    if (!hasAnyMoods) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No moods logged this week yet.',
            style: _poppins(size: 14, color: Colors.grey[500]!),
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 5,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final day = week[group.x.toInt()];
                final dominant = day.dominantEmotion;
                if (dominant == null) return null;
                return BarTooltipItem(
                  '${_emojiForEmotion(dominant)} ${dominant[0].toUpperCase()}${dominant.substring(1)}',
                  _poppins(
                      size: 13, weight: FontWeight.w600, color: Colors.white),
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
                  final idx = value.toInt();
                  if (idx >= 0 && idx < week.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        week[idx].dayLabel,
                        style: _poppins(size: 13, weight: FontWeight.w600),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(week.length, (i) {
            final day = week[i];
            final dominant = day.dominantEmotion;
            final barColor = dominant != null
                ? _colorForEmotion(dominant)
                : Colors.grey[300]!;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: day.intensity,
                  color: barColor,
                  width: 20,
                  borderRadius: BorderRadius.circular(6),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 5,
                    color: Colors.grey[100]!,
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ── Activity stats ──────────────────────────────────────────────

  Widget _buildActivityStats(ProgressData data) {
    final stats = data.activityStats;

    // Top-level numbers
    final rows = <Widget>[
      _statRow('Total Completed', '${stats.totalCompleted}', Colors.blue),
      _statRow(
        'Total Time',
        _formatDuration(stats.totalTimeSeconds),
        Colors.teal,
      ),
      _statRow(
        'Average Score',
        stats.averageScore > 0
            ? '${stats.averageScore.toStringAsFixed(0)}%'
            : '—',
        Colors.orange,
      ),
      _statRow(
        'Stars from Activities',
        '${stats.totalStarsEarned} ⭐',
        Colors.amber,
      ),
    ];

    // Per-activity breakdown
    final breakdown = stats.completionsByActivity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...rows,
        if (breakdown.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('By Activity',
              style: _poppins(size: 15, weight: FontWeight.w600)),
          const SizedBox(height: 10),
          ...breakdown.take(6).map((e) {
            final maxVal = breakdown.first.value
                .toDouble()
                .clamp(1.0, double.infinity)
                .toDouble();
            return _progressBar(e.key, e.value, maxVal);
          }),
        ],
      ],
    );
  }

  Widget _statRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: _poppins(size: 14)),
          ),
          Text(value, style: _poppins(size: 14, weight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _progressBar(String label, int count, double max) {
    final fraction = (count / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label,
                    style: _poppins(size: 13), overflow: TextOverflow.ellipsis),
              ),
              Text('$count',
                  style: _poppins(
                      size: 13,
                      weight: FontWeight.w600,
                      color: const Color(0xFF6B21A8))),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF6B21A8)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final mins = seconds ~/ 60;
    if (mins < 60) return '${mins}m';
    final hrs = mins ~/ 60;
    final remMins = mins % 60;
    return '${hrs}h ${remMins}m';
  }

  // ── Goals section (UCD024) ──────────────────────────────────────

  Widget _buildGoalsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with Add button
          Row(
            children: [
              const Icon(Icons.flag, color: Color(0xFF6B21A8), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Goals',
                    style: _poppins(size: 18, weight: FontWeight.w700)),
              ),
              TextButton.icon(
                onPressed: _openNewGoalDialog,
                icon: const Icon(Icons.add, size: 18),
                label: Text('Add New Goal',
                    style: _poppins(size: 13, weight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6B21A8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFE9D5FF)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Goal list
          if (_goals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    const Text('🎯', style: TextStyle(fontSize: 36)),
                    const SizedBox(height: 8),
                    Text(
                      'No goals yet. Tap "Add New Goal" to get started!',
                      style: _poppins(size: 14, color: Colors.grey[500]!),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ..._goals.map(_buildGoalCard),
        ],
      ),
    );
  }

  Widget _buildGoalCard(PerformanceGoal goal) {
    final isCompleted = goal.status == GoalStatus.completed;
    final statusColor = isCompleted
        ? const Color(0xFF4CAF50)
        : goal.status == GoalStatus.expired
            ? Colors.grey
            : const Color(0xFF6B21A8);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFFF1F8E9) : const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isCompleted ? const Color(0xFFC8E6C9) : const Color(0xFFE1BEE7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: category + status + delete
          Row(
            children: [
              Text(goal.category.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.category.label,
                      style: _poppins(size: 14, weight: FontWeight.w600),
                    ),
                    Text(
                      '${goal.category.unitLabel(goal.target)}  •  ${goal.duration.label}',
                      style: _poppins(size: 12, color: Colors.grey[600]!),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  goal.status.label,
                  style: _poppins(
                      size: 11, weight: FontWeight.w600, color: statusColor),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _deleteGoal(goal.id),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 18, color: Colors.grey[400]),
                ),
              ),
            ],
          ),

          // Progress bar
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: goal.progressFraction,
                    minHeight: 8,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${goal.currentProgress} / ${goal.target}',
                style: _poppins(
                    size: 12, weight: FontWeight.w600, color: statusColor),
              ),
            ],
          ),

          // Linked reward
          if (goal.linkedReward != null && goal.linkedReward!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.card_giftcard, size: 14, color: Colors.orange[700]),
                const SizedBox(width: 6),
                Text(
                  'Reward: ${goal.linkedReward}',
                  style: _poppins(
                      size: 12,
                      color: Colors.orange[700]!,
                      weight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Badge grid ──────────────────────────────────────────────────

  Widget _buildBadgeGrid(List<Badge> badges) {
    if (badges.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'Keep playing to earn your first badge!',
            style: _poppins(size: 14, color: Colors.grey[500]!),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: badges.map((b) => _badgeTile(b)).toList(),
    );
  }

  Widget _badgeTile(Badge badge) {
    return Tooltip(
      message: badge.description,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: badge.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: badge.color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(badge.emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 6),
            Text(
              badge.title,
              style: _poppins(
                  size: 12, weight: FontWeight.w600, color: badge.color),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Recent activities ───────────────────────────────────────────

  Widget _buildRecentActivities(List<CompletionRecord> records) {
    return Column(
      children: records.map((r) {
        final timeAgo = _timeAgo(r.completedAt);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E8FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B21A8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('🎮', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.activityName.isNotEmpty ? r.activityName : 'Activity',
                      style: _poppins(size: 14, weight: FontWeight.w600),
                    ),
                    Text(
                      '${r.starsEarned} ⭐  •  $timeAgo',
                      style: _poppins(size: 12, color: Colors.grey[600]!),
                    ),
                  ],
                ),
              ),
              if (r.scoreMax > 0)
                Text(
                  '${r.scoreValue}/${r.scoreMax}',
                  style: _poppins(
                      size: 14,
                      weight: FontWeight.w700,
                      color: const Color(0xFF6B21A8)),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}';
  }
}
