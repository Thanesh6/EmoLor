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

  // Day selector
  late String _selectedDay;
  late List<String> _dayOptions;

  // Category selector for progress subcategories
  int _selectedCategory = 0;
  static const _categories = ['Overview', 'Mood Patterns', 'Activity Insights', 'Time & Engagement'];
  static const _categoryIcons = [Icons.dashboard, Icons.favorite, Icons.gamepad, Icons.timer];

  static const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  List<String> _buildDayOptions() {
    final now = DateTime.now();
    final options = <String>['Today', 'Yesterday'];
    for (int i = 2; i < 14; i++) {
      final d = now.subtract(Duration(days: i));
      options.add('${_monthNames[d.month - 1]} ${d.day}');
    }
    return options;
  }

  @override
  void initState() {
    super.initState();
    _dayOptions = _buildDayOptions();
    _selectedDay = _dayOptions.first;
    _dataFuture = _loadAll();
  }

  Future<ProgressData> _loadAll() async {
    // Load emotion palette for colour mapping
    await _loadEmotionPalette();
    await _loadGoals();

    // "Today" → real data from services, fallback to sample if empty
    if (_selectedDay == 'Today') {
      final real = await _service.loadProgress();
      if (!real.isEmpty) return real;
      // Show sample data so dashboard isn't empty initially
      return _buildMockData(0);
    }

    // "Yesterday" & earlier → mock data
    return _buildMockData(_selectedDay == 'Yesterday' ? 1 : 2);
  }

  /// Generate mock/sample progress data for display
  /// weeksAgo: 0 = this week sample, 1 = last week, 2 = previous week
  ProgressData _buildMockData(int weeksAgo) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1 + 7 * weeksAgo));

    // Mock daily moods
    final weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final mockEmotions = ['happy', 'calm', 'excited', 'sad', 'happy', 'calm', 'happy'];
    final daysWithData = weeksAgo == 0 ? 3 : (weeksAgo == 1 ? 6 : 4);
    final weeklyMoods = List.generate(7, (i) {
      final day = weekStart.add(Duration(days: i));
      final hasData = i < daysWithData;
      return DailyMood(
        date: day,
        dayLabel: weekDays[i],
        entries: hasData
            ? [MoodSnapshot(emotionId: mockEmotions[i], timestamp: day.add(const Duration(hours: 10)))]
            : [],
      );
    });

    // Mock activity stats — vary by week
    final completedCount = weeksAgo == 0 ? 4 : (weeksAgo == 1 ? 8 : 5);
    final totalTime = weeksAgo == 0 ? 1200 : (weeksAgo == 1 ? 2400 : 1500);
    final mockStars = weeksAgo == 0 ? 6 : (weeksAgo == 1 ? 12 : 7);

    final activityStats = ActivityStats(
      totalCompleted: completedCount,
      totalTimeSeconds: totalTime,
      totalStarsEarned: mockStars,
      averageScore: weeksAgo == 0 ? 72.0 : (weeksAgo == 1 ? 78.0 : 65.0),
      completionsByActivity: weeksAgo == 0
          ? {'EMOZZLE': 2, 'EMOPOP': 1, 'EMOSPELL': 1}
          : (weeksAgo == 1
              ? {'EMOZZLE': 3, 'EMOPOP': 2, 'EMOSPELL': 1, 'EMOSORT': 1, 'EMOSLASH': 1}
              : {'EMOZZLE': 2, 'EMOPOP': 1, 'EMOCATCH': 1, 'EMOSORT': 1}),
    );

    // Mock completions
    final mockCompletions = [
      CompletionRecord(
        activityId: 'game_emoji_puzzle', activityName: 'EMOZZLE',
        starsEarned: 3, scoreValue: 85, scoreMax: 100,
        timeSpentSeconds: 300, completedAt: weekStart.add(const Duration(days: 2, hours: 14)),
      ),
      CompletionRecord(
        activityId: 'game_emotion_bubbles', activityName: 'EMOPOP',
        starsEarned: 2, scoreValue: 70, scoreMax: 100,
        timeSpentSeconds: 240, completedAt: weekStart.add(const Duration(days: 3, hours: 10)),
      ),
      CompletionRecord(
        activityId: 'game_emotion_sorting', activityName: 'EMOSORT',
        starsEarned: 1, scoreValue: 60, scoreMax: 100,
        timeSpentSeconds: 180, completedAt: weekStart.add(const Duration(days: 4, hours: 16)),
      ),
    ];

    return ProgressData(
      weeklyMoods: weeklyMoods,
      activityStats: activityStats,
      starBreakdown: weeksAgo == 0
          ? {'emoji_puzzle': 3, 'emotion_bubbles': 2, 'emoji_spell': 1}
          : (weeksAgo == 1
              ? {'emoji_puzzle': 5, 'emotion_bubbles': 3, 'emoji_spell': 2, 'emotion_sorting': 2}
              : {'emoji_puzzle': 3, 'emotion_bubbles': 2, 'emotion_catcher': 2}),
      totalStars: mockStars,
      earnedBadges: weeksAgo <= 1
          ? [Badge(id: 'first_star', title: 'First Star', emoji: '⭐', description: 'Earned first star', color: Colors.orange)]
          : [],
      recentCompletions: mockCompletions,
    );
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
    return GoogleFonts.baloo2(
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
    final isToday = _selectedDay == 'Today';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isToday ? '🎮' : '📊', style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            isToday ? 'No activities today yet' : 'No data available',
            style: _poppins(size: 20, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            isToday
                ? 'Play some games and your progress will show up here!'
                : 'No progress was recorded for this date.',
            style: _poppins(size: 15, color: Colors.grey[600]!),
          ),
        ],
      ),
    );
  }

  // ── Main dashboard ──────────────────────────────────────────────

  Widget _buildCategoryChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: List.generate(_categories.length, (i) {
          final selected = _selectedCategory == i;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => setState(() => _selectedCategory = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF6B21A8) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: selected ? [
                      BoxShadow(
                        color: const Color(0xFF6B21A8).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ] : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_categoryIcons[i], size: 22, color: selected ? Colors.white : const Color(0xFF6B21A8)),
                      const SizedBox(height: 6),
                      Text(
                        _categories[i],
                        style: _poppins(
                          size: 13,
                          weight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? Colors.white : const Color(0xFF6B21A8),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDashboard(ProgressData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with week selector
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress Dashboard',
                      style: _poppins(
                        size: 34,
                        weight: FontWeight.w700,
                        color: const Color(0xFF6B21A8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Daily overview of your child\'s learning journey',
                      style: _poppins(size: 18, weight: FontWeight.w600, color: Colors.grey[600]!),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (val) {
                  setState(() {
                    _selectedDay = val;
                    _dataFuture = _loadAll();
                  });
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                offset: const Offset(0, 50),
                itemBuilder: (_) => _dayOptions.map((d) => PopupMenuItem(
                  value: d,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        d == _selectedDay ? Icons.check_circle : Icons.circle_outlined,
                        color: const Color(0xFF6B21A8),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(d, style: _poppins(size: 16, weight: d == _selectedDay ? FontWeight.w700 : FontWeight.w500)),
                    ],
                  ),
                )).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE9D5FF)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, color: Color(0xFF6B21A8), size: 22),
                      const SizedBox(width: 10),
                      Text(_selectedDay, style: _poppins(size: 18, weight: FontWeight.w600, color: const Color(0xFF6B21A8))),
                      const SizedBox(width: 8),
                      const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6B21A8), size: 22),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Category chips
          _buildCategoryChips(),
          const SizedBox(height: 24),

          // Category-specific content
          if (_selectedCategory == 0) ..._buildOverviewContent(data),
          if (_selectedCategory == 1) ..._buildMoodPatternsContent(data),
          if (_selectedCategory == 2) ..._buildActivityInsightsContent(data),
          if (_selectedCategory == 3) ..._buildTimeEngagementContent(data),
        ],
      ),
    );
  }

  /// Overview — just the summary stat cards
  List<Widget> _buildOverviewContent(ProgressData data) {
    return [
      _buildSummaryRow(data),
      const SizedBox(height: 24),
      // Quick mood snapshot + activity completion side by side
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _buildSection(
                title: 'Mood This Week',
                icon: Icons.insights,
                subtitle:
                    'Emotions expressed on the week — positive vs negative shifts',
                child: _buildMoodChart(data.weeklyMoods),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSection(
                title: 'Top Emotions',
                icon: Icons.favorite,
                child: _buildTopEmotionsChart(data),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// Mood Patterns — emotion trends + top emotions + emotion distribution
  List<Widget> _buildMoodPatternsContent(ProgressData data) {
    return [
      _buildSection(
        title: 'Weekly Mood Trends',
        icon: Icons.insights,
        subtitle:
            'Emotions expressed on the week — positive vs negative shifts',
        child: _buildMoodChart(data.weeklyMoods),
      ),
      const SizedBox(height: 24),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _buildSection(
                title: 'Emotion Distribution',
                icon: Icons.pie_chart,
                child: _buildTopEmotionsChart(data),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSection(
                title: 'Emotion Frequency',
                icon: Icons.bar_chart,
                child: _buildEmotionFrequencyBars(data),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// Activity Insights — completion stats + per-activity breakdown
  List<Widget> _buildActivityInsightsContent(ProgressData data) {
    return [
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _buildSection(
                title: 'Activity Completion',
                icon: Icons.emoji_events,
                child: _buildActivityStats(data),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSection(
                title: 'Daily Activity',
                icon: Icons.show_chart,
                child: _buildDailyActivityChart(data),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// Time & Engagement — engagement per game + daily patterns
  List<Widget> _buildTimeEngagementContent(ProgressData data) {
    return [
      _buildSection(
        title: 'Time Per Game',
        icon: Icons.timer_outlined,
        child: _buildEngagementChart(data),
      ),
      const SizedBox(height: 24),
      _buildSection(
        title: 'Daily Activity Trend',
        icon: Icons.show_chart,
        child: _buildDailyActivityChart(data),
      ),
    ];
  }

  /// Recent History — recent activity list (simple layout, no heavy wrapper)
  List<Widget> _buildRecentHistoryContent(ProgressData data) {
    if (data.recentCompletions.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Center(
            child: Column(
              children: [
                const Text('🎮', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text('No recent activities yet', style: _poppins(size: 18, weight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('Activities will appear here after your child plays games',
                    style: _poppins(size: 14, color: Colors.grey[500]!)),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      _buildRecentActivities(data.recentCompletions),
    ];
  }

  /// Emotion frequency horizontal bars (uses real data from weeklyMoods)
  Widget _buildEmotionFrequencyBars(ProgressData data) {
    // Tally emotions from weekly moods
    final freq = <String, int>{};
    for (final day in data.weeklyMoods) {
      for (final entry in day.entries) {
        freq[entry.emotionId] = (freq[entry.emotionId] ?? 0) + 1;
      }
    }

    // Sample entries if no real data
    if (freq.isEmpty) {
      freq['happy'] = 7;
      freq['calm'] = 5;
      freq['excited'] = 4;
      freq['sad'] = 2;
      freq['angry'] = 1;
      freq['scared'] = 1;
    }

    final sorted = freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.first.value.toDouble();

    return Column(
      children: sorted.take(6).map((e) {
        final fraction = (e.value / maxVal).clamp(0.0, 1.0);
        final emoji = _emojiForEmotion(e.key);
        final color = _colorForEmotion(e.key);
        final name = e.key[0].toUpperCase() + e.key.substring(1);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              SizedBox(
                width: 70,
                child: Text(name, style: _poppins(size: 13, weight: FontWeight.w600)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 14,
                    backgroundColor: Colors.grey[100],
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${e.value}x', style: _poppins(size: 13, weight: FontWeight.w700, color: const Color(0xFF6B21A8))),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Summary row ─────────────────────────────────────────────────

  Widget _buildSummaryRow(ProgressData data) {
    final totalMins = data.activityStats.totalTimeSeconds ~/ 60;
    final hoursStr = totalMins >= 60
        ? '${(totalMins / 60).toStringAsFixed(1)}'
        : '$totalMins';
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
            'Rewards',
            '${data.earnedBadges.length}',
            Colors.purple,
          ),
          _summaryCard(
            '⏱️',
            'Hours Active',
            hoursStr,
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
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: _poppins(size: 36, weight: FontWeight.w700)),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(label, style: _poppins(size: 22, color: Colors.grey[600]!)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section wrapper ─────────────────────────────────────────────

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
    String? subtitle,
    Widget? trailing,
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
              Icon(icon, color: const Color(0xFF6B21A8), size: 26),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: _poppins(size: 26, weight: FontWeight.w700))),
              if (trailing != null) trailing,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Text(
                subtitle,
                style: _poppins(
                    size: 14,
                    weight: FontWeight.w500,
                    color: Colors.grey[600]!),
              ),
            ),
          ],
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  // ── Mood bar chart ──────────────────────────────────────────────

  // Positive vs negative emotion classification
  static const Set<String> _positiveEmotionIds = {
    'joy', 'trust', 'anticipation', 'surprise',
    'happy', 'calm', 'excited',
  };
  static const Set<String> _negativeEmotionIds = {
    'fear', 'sadness', 'disgust', 'anger',
    'sad', 'angry', 'scared',
  };

  /// Weekly dual-line chart: positive vs negative emotion frequency per day.
  /// X-axis: Day 1 → Day 7, Y-axis: frequency (0–10).
  Widget _buildMoodChart(List<DailyMood> week) {
    // Tally positive/negative counts per day from real data
    final positiveCounts = List<double>.filled(7, 0);
    final negativeCounts = List<double>.filled(7, 0);
    for (int i = 0; i < 7 && i < week.length; i++) {
      for (final entry in week[i].entries) {
        final id = entry.emotionId.toLowerCase();
        if (_positiveEmotionIds.contains(id)) {
          positiveCounts[i]++;
        } else if (_negativeEmotionIds.contains(id)) {
          negativeCounts[i]++;
        }
      }
    }

    // If no real data, use illustrative mock samples so the chart is readable.
    final hasAnyData =
        positiveCounts.any((v) => v > 0) || negativeCounts.any((v) => v > 0);
    if (!hasAnyData) {
      final pos = [3.0, 5.0, 4.0, 7.0, 6.0, 8.0, 9.0];
      final neg = [6.0, 5.0, 4.0, 3.0, 4.0, 2.0, 1.0];
      for (int i = 0; i < 7; i++) {
        positiveCounts[i] = pos[i];
        negativeCounts[i] = neg[i];
      }
    }

    const posColor = Color(0xFF22C55E); // green
    const negColor = Color(0xFFEF4444); // red

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend
        Row(
          children: [
            _legendDot(posColor, 'Positive'),
            const SizedBox(width: 18),
            _legendDot(negColor, 'Negative'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 6,
              minY: 0,
              maxY: 10,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 5,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.grey[200]!,
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx >= 0 && idx < 7) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Day ${idx + 1}',
                            style: _poppins(
                                size: 12, weight: FontWeight.w600),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, _) {
                      // Only draw labels at 0, 1, 5, 10
                      if (value == 0 ||
                          value == 1 ||
                          value == 5 ||
                          value == 10) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            value.toInt().toString(),
                            style: _poppins(
                                size: 12, weight: FontWeight.w600),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) {
                    final isPos = s.barIndex == 0;
                    return LineTooltipItem(
                      '${isPos ? "Positive" : "Negative"}: ${s.y.toInt()}',
                      _poppins(
                          size: 12,
                          weight: FontWeight.w600,
                          color: Colors.white),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                // Positive line
                LineChartBarData(
                  spots: List.generate(
                      7, (i) => FlSpot(i.toDouble(), positiveCounts[i])),
                  isCurved: true,
                  color: posColor,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 4.5,
                      color: posColor,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: posColor.withValues(alpha: 0.12),
                  ),
                ),
                // Negative line
                LineChartBarData(
                  spots: List.generate(
                      7, (i) => FlSpot(i.toDouble(), negativeCounts[i])),
                  isCurved: true,
                  color: negColor,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 4.5,
                      color: negColor,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: negColor.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: _poppins(size: 13, weight: FontWeight.w600)),
      ],
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
              style: _poppins(size: 19, weight: FontWeight.w600)),
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
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: _poppins(size: 18)),
          ),
          Text(value, style: _poppins(size: 18, weight: FontWeight.w700)),
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
                    style: _poppins(size: 16), overflow: TextOverflow.ellipsis),
              ),
              Text('$count',
                  style: _poppins(
                      size: 16,
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

  // ── Daily Activity Line Chart ─────────────────────────────────
  Widget _buildDailyActivityChart(ProgressData data) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    // Use mock counts per day with some sample entries so chart is not empty
    final counts = List.generate(7, (i) {
      final real = i < data.weeklyMoods.length ? data.weeklyMoods[i].entries.length.toDouble() : 0.0;
      // Fallback sample if all zero
      final samples = [2.0, 3.0, 1.0, 4.0, 2.0, 3.0, 1.0];
      return real > 0 ? real : samples[i];
    });
    final maxY = counts.fold<double>(0, (a, b) => a > b ? a : b).clamp(1.0, double.infinity);

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 6,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey[200]!,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < days.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(days[idx], style: _poppins(size: 13, weight: FontWeight.w600)),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minY: 0,
          maxY: maxY + 1,
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(7, (i) => FlSpot(i.toDouble(), counts[i])),
              isCurved: true,
              color: const Color(0xFF6B21A8),
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 5,
                  color: const Color(0xFF6B21A8),
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF6B21A8).withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Engagement Time Bar Chart ─────────────────────────────────
  Widget _buildEngagementChart(ProgressData data) {
    final games = ['EMOZZLE', 'EMOPOP', 'EMOSPELL', 'EMOSORT', 'EMOSLASH', 'EMOCATCH'];
    final colors = [Colors.purple, Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.teal];
    // Sample engagement minutes per game
    final mins = [18.0, 12.0, 15.0, 8.0, 22.0, 10.0];

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 25,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) {
                return BarTooltipItem(
                  '${games[group.x.toInt()]}\n${rod.toY.toInt()} min',
                  _poppins(size: 12, weight: FontWeight.w600, color: Colors.white),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < games.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        games[idx].substring(0, 4),
                        style: _poppins(size: 11, weight: FontWeight.w600),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(games.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: mins[i],
                  color: colors[i],
                  width: 22,
                  borderRadius: BorderRadius.circular(6),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 25,
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

  // ── Top Emotions Pie Chart ────────────────────────────────────
  Widget _buildTopEmotionsChart(ProgressData data) {
    // Tally emotions from weekly moods (real data)
    final freq = <String, int>{};
    for (final day in data.weeklyMoods) {
      for (final entry in day.entries) {
        freq[entry.emotionId] = (freq[entry.emotionId] ?? 0) + 1;
      }
    }

    // Fallback sample data if no real entries
    if (freq.isEmpty) {
      freq['happy'] = 7;
      freq['calm'] = 5;
      freq['excited'] = 4;
      freq['sad'] = 2;
      freq['angry'] = 2;
    }

    final total = freq.values.fold(0, (a, b) => a + b).toDouble();
    final sorted = freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 35,
              sections: top.map((e) {
                final pct = total > 0 ? (e.value / total * 100) : 0.0;
                final color = _colorForEmotion(e.key);
                return PieChartSectionData(
                  value: e.value.toDouble(),
                  color: color,
                  radius: 40,
                  title: '${pct.toInt()}%',
                  titleStyle: _poppins(size: 12, weight: FontWeight.w700, color: Colors.white),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: top.map((e) {
            final pct = total > 0 ? (e.value / total * 100) : 0.0;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_emojiForEmotion(e.key), style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  '${e.key[0].toUpperCase()}${e.key.substring(1)} ${pct.toInt()}%',
                  style: _poppins(size: 14, weight: FontWeight.w600),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
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
              const Icon(Icons.flag, color: Color(0xFF6B21A8), size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Goals',
                    style: _poppins(size: 26, weight: FontWeight.w700)),
              ),
              ElevatedButton.icon(
                onPressed: _openNewGoalDialog,
                icon: const Icon(Icons.add, size: 22),
                label: Text('Add New Goal',
                    style: _poppins(size: 16, weight: FontWeight.w600, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B21A8),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Goal list
          if (_goals.isEmpty)
            ..._buildSampleGoals()
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
              Text(goal.category.emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.category.label,
                      style: _poppins(size: 22, weight: FontWeight.w600),
                    ),
                    Text(
                      '${goal.category.unitLabel(goal.target)}  •  ${goal.duration.label}',
                      style: _poppins(size: 18, color: Colors.grey[600]!),
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
                      size: 17, weight: FontWeight.w600, color: statusColor),
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
                    size: 22, weight: FontWeight.w600, color: statusColor),
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

  // ── Sample emotion bars (shown when no moods logged) ───────────

  Widget _buildSampleEmotionBars() {
    final sampleEmotions = [
      {'label': 'Happy', 'value': 0.8, 'color': Colors.green},
      {'label': 'Calm', 'value': 0.65, 'color': Colors.blue},
      {'label': 'Excited', 'value': 0.45, 'color': Colors.orange},
      {'label': 'Tired', 'value': 0.25, 'color': Colors.grey},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sampleEmotions.map((e) {
        final label = e['label'] as String;
        final value = e['value'] as double;
        final color = e['color'] as Color;
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style: _poppins(size: 23, weight: FontWeight.w600)),
                  Text('${(value * 100).toInt()}%',
                      style: _poppins(
                          size: 23, color: color, weight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Sample goals (shown when no goals set) ────────────────────

  List<Widget> _buildSampleGoals() {
    final sampleGoals = [
      {
        'label': 'Complete 5 activities',
        'progress': 0.6,
        'current': 3,
        'target': 5,
        'color': Colors.blue,
        'emoji': '🎮',
      },
      {
        'label': 'Earn 10 stars',
        'progress': 0.4,
        'current': 4,
        'target': 10,
        'color': Colors.orange,
        'emoji': '⭐',
      },
      {
        'label': 'Log emotions daily',
        'progress': 0.85,
        'current': 6,
        'target': 7,
        'color': Colors.green,
        'emoji': '📝',
      },
    ];

    return sampleGoals.map((g) {
      final label = g['label'] as String;
      final progress = g['progress'] as double;
      final current = g['current'] as int;
      final target = g['target'] as int;
      final color = g['color'] as Color;
      final emoji = g['emoji'] as String;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E8FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE1BEE7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 34)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label,
                      style: _poppins(size: 22, weight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.grey[200],
                      valueColor:
                          AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$current / $target',
                  style: _poppins(
                      size: 22, weight: FontWeight.w600, color: color),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
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

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: badges.map((b) => _badgeTile(b)).toList(),
      ),
    );
  }

  Widget _badgeTile(Badge badge) {
    return Tooltip(
      message: badge.description,
      child: Container(
        width: 138,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: badge.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: badge.color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(badge.emoji, style: const TextStyle(fontSize: 41)),
            const SizedBox(height: 6),
            Text(
              badge.title,
              style: _poppins(
                  size: 17, weight: FontWeight.w600, color: badge.color),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B21A8).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(r.scoreValue * 100 / r.scoreMax).round()}%',
                    style: _poppins(
                        size: 14,
                        weight: FontWeight.w700,
                        color: const Color(0xFF6B21A8)),
                  ),
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
