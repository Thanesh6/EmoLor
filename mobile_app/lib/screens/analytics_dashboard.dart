import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/ai_insight_service.dart';
import '../core/services/emotion_colour_mapping.dart';
import '../core/services/emotion_journal_service.dart';
import '../core/services/star_service.dart';
import '../features/caregiver/presentation/widgets/new_goal_dialog.dart';
import '../features/caregiver/services/goal_service.dart';
import '../features/caregiver/services/pdf_report_service.dart';
import '../features/child/services/child_rewards_service.dart';
import '../features/child/services/child_session_service.dart';
import '../features/child/services/completion_service.dart';
import '../features/child/models/completion_record.dart';

class AnalyticsDashboard extends StatefulWidget {
  final String? childName;
  final bool showSwitchAccount;

  const AnalyticsDashboard({
    super.key,
    this.childName,
    this.showSwitchAccount = false,
  });

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedNavIndex = 0;
  String _caregiverName = 'Caregiver';
  String _childName = 'Child';
  String _childAvatar = '🐱';
  late AnimationController _glowCtrl;

  String? _childUserId; // child's Supabase user_id for linking codes

  // ── Real-time data from services ──
  int _totalStars = 0;
  int _rewardsUnlocked = 0;
  int _totalActivities = 0;
  int _todayActivities = 0;
  int _weekExpressions = 0;
  Map<String, int> _emotionFreq = {};
  Map<String, int> _gameFreq = {};
  List<CompletionRecord> _recentCompletions = [];
  List<Map<String, dynamic>> _recentJournal = [];
  List<Map<String, dynamic>> _activeGoals = [];

  List<Map<String, dynamic>> _childSessions = [];

  // ── Week selector offset for Home tab (0 = this week, -1 = last week …) ──
  int _selectedWeekOffset = 0;

  // ── On-demand AI insight summary (Progress tab) ──
  // null = never generated for the current selection.
  // Cleared whenever the user changes weeks so the panel re-prompts.
  String? _aiInsight;
  bool _aiLoading = false;
  String? _aiError;

  // ── Full completion history — used by week-filtered Home tab cards ──
  List<CompletionRecord> _allCompletions = [];

  // ── Extended analytics ──
  int _currentStreak = 0;
  int _weekActivities = 0;
  String _todayEmotion = '—';
  String _todayEmotionEmoji = '😶';
  String _lastActiveText = 'Never';
  List<int> _dailyActivityCounts = List.filled(7, 0);
  Map<String, double> _gameAvgStars = {};
  Map<String, int> _gamePlayCounts = {};
  Map<String, int> _activityDiversity = {};
  List<double> _weeklyStarTotals = List.filled(8, 0);
  Map<String, int> _timeOfDayEmotions = {
    'Morning': 0,
    'Afternoon': 0,
    'Evening': 0
  };

  // ── 7-Day Metrics ──
  String _mostFreqEmotion7D = '—';
  String _mostFreqEmotionPct7D = '0%';
  int _activeDays7D = 0;
  String _mostPlayedGame7D = '—';
  String _mostPlayedGameTime7D = '';
  int _completionRate7D = 0;
  String _avgDailyMins7D = '0';
  String _smartInsight7D = '✅ Steady engagement';
  // Minutes spent per activity over the last 7 days, keyed by raw
  // activity id ('EMOZZLE', 'EMOPOP', ... , 'Draw'). Feeds the
  // Activity Performance bar chart.
  Map<String, int> _gameMinutes7D = {};
  bool _isLoading = true;

  // Tracks which pie slice is currently tapped in each distribution panel.
  int _touchedPositiveSection = -1;
  int _touchedNegativeSection = -1;

  @override
  void initState() {
    super.initState();
    _childName = widget.childName ?? 'Child';
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addObserver(this);
    _loadCaregiverProfile();
    _loadChildProfile();
    _loadRealData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh data when app comes back to foreground (after playing games)
    if (state == AppLifecycleState.resumed) {
      _loadRealData();
    }
  }

  /// Load all real data from local services
  Future<void> _loadRealData() async {
    try {
      await EmotionColourMapping.ensureLoaded();
      final stars = await StarService.getTotalStars();
      final rewards = await ChildRewardsService.getUnlockedCount();
      final completions = await CompletionService.history();
      final emotionFreq = await EmotionJournalService.getEmotionFrequency();
      final gameFreq = await EmotionJournalService.getGameFrequency();
      final journal = await EmotionJournalService.getEntries();

      // Calculate today's activities
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayCompletions =
          completions.where((c) => c.completedAt.isAfter(todayStart)).toList();

      // This week's expressions (journal entries)
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDate =
          DateTime(weekStart.year, weekStart.month, weekStart.day);
      final weekExpressions = journal.where((e) {
        final ts = DateTime.parse(e['timestamp'] as String);
        return ts.isAfter(weekStartDate);
      }).length;

      // Load user-created goals with REAL progress values (must be outside
      // setState — it's async). Replaces the previous code path that mapped
      // every goal to `current: 0`, leaving every progress bar stuck empty.
      final activeGoalsLive = await _activeGoalsWithProgress();
      final childSessions = await ChildSessionService.getRecentSessions(limit: 30);

      // ── Extended analytics ──
      final activeDayKeys = completions.map((c) {
        final d = c.completedAt.toLocal();
        return '${d.year}-${d.month}-${d.day}';
      }).toSet();

      // Current streak
      int streak = 0;
      for (int i = 0; i < 30; i++) {
        final d = now.subtract(Duration(days: i));
        if (activeDayKeys.contains('${d.year}-${d.month}-${d.day}')) {
          streak++;
        } else {
          break;
        }
      }

      // Week activities (last 7 days)
      final sevenDaysAgo = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 6));
      final weekActivities =
          completions.where((c) => c.completedAt.isAfter(sevenDaysAgo)).length;

      // Daily counts for bar chart
      final dailyCounts = List.filled(7, 0);
      for (int i = 0; i < 7; i++) {
        final day = now.subtract(Duration(days: 6 - i));
        final ds = DateTime(day.year, day.month, day.day);
        final de = ds.add(const Duration(days: 1));
        dailyCounts[i] = completions
            .where(
                (c) => c.completedAt.isAfter(ds) && c.completedAt.isBefore(de))
            .length;
      }

      // Today's emotion (last journal entry today)
      String todayEmotion = '—';
      String todayEmotionEmoji = '😶';
      final todayJournal = journal.where((e) {
        final ts =
            DateTime.tryParse(e['timestamp'] as String? ?? '')?.toLocal();
        return ts != null &&
            ts.year == now.year &&
            ts.month == now.month &&
            ts.day == now.day;
      }).toList();
      if (todayJournal.isNotEmpty) {
        todayEmotion = todayJournal.last['emotion'] as String? ?? '—';
        todayEmotionEmoji = todayJournal.last['emoji'] as String? ?? '😊';
      }

      // Last active
      String lastActiveText = 'Never';
      if (completions.isNotEmpty) {
        final latest = completions
            .reduce((a, b) => a.completedAt.isAfter(b.completedAt) ? a : b);
        lastActiveText = _timeAgo(latest.completedAt.toIso8601String());
      }

      // Per-game avg stars
      final Map<String, int> gamePlays = {};
      final Map<String, int> gameStarSum = {};
      for (final c in completions) {
        gamePlays[c.activityName] = (gamePlays[c.activityName] ?? 0) + 1;
        gameStarSum[c.activityName] =
            (gameStarSum[c.activityName] ?? 0) + c.starsEarned;
      }
      final Map<String, double> gameAvgStars = {};
      for (final g in gamePlays.keys) {
        gameAvgStars[g] =
            gamePlays[g]! > 0 ? gameStarSum[g]! / gamePlays[g]! : 0.0;
      }

      // Activity diversity
      const coreGames = [
        'EMOZZLE',
        'EMOPOP',
        'EMOSPELL',
        'EMOSORT',
        'EMOSLASH',
        'EMOCATCH'
      ];
      final actDiversity = <String, int>{
        'Games':
            completions.where((c) => coreGames.contains(c.activityName)).length,
        'Draw': completions.where((c) => c.activityName == 'Draw').length,
        'Express Cards':
            completions.where((c) => c.activityName == 'Express Cards').length,
        'My Colours':
            completions.where((c) => c.activityName == 'My Colours').length,
      };

      // Weekly star totals (last 8 weeks)
      final weeklyStars = List<double>.filled(8, 0);
      for (final c in completions) {
        final weeksAgo = now.difference(c.completedAt).inDays ~/ 7;
        if (weeksAgo >= 0 && weeksAgo < 8)
          weeklyStars[7 - weeksAgo] += c.starsEarned;
      }

      // Time of day emotions
      final Map<String, int> timeOfDay = {
        'Morning': 0,
        'Afternoon': 0,
        'Evening': 0
      };
      for (final e in journal) {
        final ts =
            DateTime.tryParse(e['timestamp'] as String? ?? '')?.toLocal();
        if (ts == null) continue;
        if (ts.hour >= 6 && ts.hour < 12)
          timeOfDay['Morning'] = timeOfDay['Morning']! + 1;
        else if (ts.hour >= 12 && ts.hour < 18)
          timeOfDay['Afternoon'] = timeOfDay['Afternoon']! + 1;
        else
          timeOfDay['Evening'] = timeOfDay['Evening']! + 1;
      }

      // ── 7-DAY FLASHCARD METRICS ──
      final sevenDaysAgoTime = now.subtract(const Duration(days: 7));

      // 1. Most Frequent Emotion (Weekly)
      final recentEmotions = journal.where((e) {
        final ts =
            DateTime.tryParse(e['timestamp'] as String? ?? '')?.toLocal() ??
                now;
        return ts.isAfter(sevenDaysAgoTime);
      }).toList();

      Map<String, int> freq7Days = {};
      for (final e in recentEmotions) {
        final em = e['emotion'] as String? ?? '';
        if (em.isNotEmpty) freq7Days[em] = (freq7Days[em] ?? 0) + 1;
      }

      String topE = 'Happy';
      String topEPct = '0%';
      int happyCount = freq7Days['Happy'] ?? 0;
      int calmCount = freq7Days['Calm'] ?? 0;
      int angryCount = freq7Days['Angry'] ?? 0;
      int sadCount = freq7Days['Sad'] ?? 0;

      if (freq7Days.isNotEmpty) {
        final sorted = freq7Days.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final highest = sorted.first;
        final totalEv = freq7Days.values.fold(0, (sum, val) => sum + val);
        final pctVal = (highest.value / totalEv) * 100;

        if (pctVal > 50) {
          topE = highest.key;
        } else {
          if ((happyCount + calmCount) > (angryCount + sadCount)) {
            topE = 'Mostly Positive';
          } else if ((angryCount + sadCount) > (happyCount + calmCount)) {
            topE = 'Needs Attention';
          } else {
            topE = 'Mixed';
          }
        }
        topEPct = '${pctVal.toStringAsFixed(0)}%';
      }

      // 2. Active Days
      final recentCompletions7D = completions
          .where((c) => c.completedAt.isAfter(sevenDaysAgoTime))
          .toList();
      final activeDaysSet = <String>{};
      for (final e in recentEmotions) {
        final ts =
            DateTime.tryParse(e['timestamp'] as String? ?? '')?.toLocal() ??
                now;
        activeDaysSet.add('${ts.year}-${ts.month}-${ts.day}');
      }
      for (final c in recentCompletions7D) {
        final ts = c.completedAt.toLocal();
        activeDaysSet.add('${ts.year}-${ts.month}-${ts.day}');
      }
      int uniqueActiveDays = activeDaysSet.length;

      // 3. Most Played Activity
      // 7 games from the Play screen + 1 Draw activity.
      const validActivities = [
        'EMOZZLE',
        'EMOPOP',
        'EMOSPELL',
        'EMOMATCH',
        'EMOSLASH',
        'EMOCATCH',
        'ANIMATCH',
        'Draw',
      ];

      Map<String, int> gameTime7Days = {};
      int totalDuration7D = 0;
      int totalScore7D = 0;
      int maxScore7D = 0;

      for (final c in recentCompletions7D) {
        if (!validActivities.contains(c.activityName)) continue;

        gameTime7Days[c.activityName] =
            (gameTime7Days[c.activityName] ?? 0) + c.timeSpentSeconds;
        totalDuration7D += c.timeSpentSeconds;
        totalScore7D += c.scoreValue;
        maxScore7D += max(1, c.scoreMax > 0 ? c.scoreMax : 3);
      }

      String mostPlayedG = '—';
      String mostPlayedTime = '0 mins';
      if (gameTime7Days.isNotEmpty) {
        final sortedGames = gameTime7Days.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final rawName = sortedGames.first.key;
        mostPlayedG = _brandedGameName(rawName);

        mostPlayedTime =
            '${(sortedGames.first.value / 60).toStringAsFixed(0)} mins';
      }

      // 4. Completion Rate
      int compRate = 100;
      if (maxScore7D > 0) {
        compRate = ((totalScore7D / maxScore7D) * 100).toInt();
        if (compRate > 100) compRate = 100;
      } else if (recentCompletions7D.isEmpty) {
        compRate = 0;
      }

      // 5. Avg Daily Usage
      final validDaysForAvg = max(1, uniqueActiveDays);
      final avgMins = (totalDuration7D / 60) / validDaysForAvg;

      // 6. Smart Insight
      String insight = '😊 Positive emotional pattern';
      if ((angryCount + sadCount) > (happyCount + 0)) {
        insight = '⚠️ More frustration detected this week';
      } else if (compRate > 80 && recentCompletions7D.isNotEmpty) {
        insight = '✅ High engagement this week';
      } else if (uniqueActiveDays < 3) {
        insight = '⚠️ Low usage this week';
      }

      // No mock-data fallback — for new profiles every metric stays at
      // its real default ("—" / "0 mins" / 0%) until the child actually
      // plays a session. This is required so caregivers see an empty
      // dashboard for a brand-new child rather than fictitious history.

      if (mounted) {
        setState(() {
          _totalStars = stars;
          _rewardsUnlocked = rewards;
          _totalActivities = completions.length;
          _todayActivities = todayCompletions.length;
          _weekExpressions = weekExpressions;
          _emotionFreq = emotionFreq;
          _gameFreq = gameFreq;
          _recentCompletions = completions.take(5).toList();
          _allCompletions = completions;
          _recentJournal = journal.reversed.toList();
          _activeGoals = activeGoalsLive;

          _currentStreak = streak;
          _weekActivities = weekActivities;
          _dailyActivityCounts = dailyCounts;
          _todayEmotion = todayEmotion;
          _todayEmotionEmoji = todayEmotionEmoji;
          _lastActiveText = lastActiveText;
          _gameAvgStars = gameAvgStars;
          _gamePlayCounts = gamePlays;
          _activityDiversity = actDiversity;
          _weeklyStarTotals = weeklyStars;
          _timeOfDayEmotions = timeOfDay;

          // ── 7-Day bindings ──
          _mostFreqEmotion7D = topE;
          _mostFreqEmotionPct7D = topEPct;
          _activeDays7D = uniqueActiveDays;
          _mostPlayedGame7D = mostPlayedG;
          _mostPlayedGameTime7D = mostPlayedTime;
          _completionRate7D = compRate;
          _avgDailyMins7D = avgMins.toStringAsFixed(0);
          _smartInsight7D = insight;
          // Convert seconds → whole minutes so the Activity Performance
          // bar chart can render "time spent per activity" directly.
          _gameMinutes7D = {
            for (final e in gameTime7Days.entries) e.key: (e.value / 60).round(),
          };

          _childSessions = childSessions;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadChildProfile() async {
    if (widget.childName != null && widget.childName!.isNotEmpty) return;
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final link = await Supabase.instance.client
          .from('family_links')
          .select('child_id')
          .eq('caregiver_id', userId)
          .maybeSingle();
      if (link != null) {
        final childId = link['child_id'] as String;
        final childProfile = await Supabase.instance.client
            .from('profiles')
            .select('full_name, avatar_url')
            .eq('user_id', childId)
            .maybeSingle();
        if (mounted && childProfile != null) {
          setState(() {
            _childUserId = childId;
            final name = childProfile['full_name'] as String?;
            if (name != null && name.isNotEmpty) _childName = name;
            final av = childProfile['avatar_url'] as String?;
            if (av != null && av.isNotEmpty) _childAvatar = av;
          });
        }
      }
      if (_childName == 'Child') {
        final rpcResult = await Supabase.instance.client
            .rpc('get_user_role', params: {'p_user_id': userId});
        if (mounted && rpcResult is List && rpcResult.isNotEmpty) {
          final row = rpcResult.first as Map<String, dynamic>;
          final name = row['full_name'] as String?;
          if (name != null && name.isNotEmpty) {
            setState(() => _childName = name);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadCaregiverProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('user_id', userId)
          .maybeSingle();
      if (mounted && profile != null) {
        setState(() {
          final name = profile['full_name'] as String?;
          if (name != null && name.isNotEmpty) _caregiverName = name;
        });
      }
    } catch (_) {}
  }

  TextStyle _textStyle({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w600,
    Color color = Colors.black87,
  }) {
    return GoogleFonts.baloo2(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  /// Map the internal ALL-CAPS game id (as stored in completion records /
  /// journal entries) to the branded Title-case name shown on the Play
  /// screen: Emozzle, Emopop, Emospell, Emomatch, Emoslash, Emocatch,
  /// Animatch — plus the Draw activity. Falls back to title-casing the
  /// raw id so unknown values still look consistent.
  String _brandedGameName(String rawName) {
    switch (rawName) {
      case 'EMOZZLE':
        return 'Emozzle';
      case 'EMOPOP':
        return 'Emopop';
      case 'EMOSPELL':
        return 'Emospell';
      case 'EMOMATCH':
        return 'Emomatch';
      case 'EMOSLASH':
        return 'Emoslash';
      case 'EMOCATCH':
        return 'Emocatch';
      case 'ANIMATCH':
        return 'Animatch';
      case 'Draw':
        return 'Draw';
      default:
        if (rawName.isEmpty) return rawName;
        return rawName[0].toUpperCase() +
            rawName.substring(1).toLowerCase();
    }
  }

  /// Build the active-goals list with **real** progress values pulled from
  /// the same data sources the rest of the dashboard uses
  /// (StarService, CompletionService, EmotionJournalService).
  ///
  /// Window per duration:
  ///   today      → since 00:00 today
  ///   thisWeek   → since Monday 00:00
  ///   thisMonth  → since the 1st 00:00
  /// Goals created mid-window count from their createdAt instead, so the bar
  /// never includes activity that happened before the goal was set.
  Future<List<Map<String, dynamic>>> _activeGoalsWithProgress() async {
    final goals = await GoalService.getAllGoals();
    if (goals.isEmpty) return [];

    final completions = await CompletionService.history();
    final journal = await EmotionJournalService.getEntries();
    final totalStars = await StarService.getTotalStars();
    final now = DateTime.now();

    DateTime windowStart(GoalDuration d, DateTime createdAt) {
      DateTime period;
      switch (d) {
        case GoalDuration.today:
          period = DateTime(now.year, now.month, now.day);
          break;
        case GoalDuration.thisWeek:
          final ws = now.subtract(Duration(days: now.weekday - 1));
          period = DateTime(ws.year, ws.month, ws.day);
          break;
        case GoalDuration.thisMonth:
          period = DateTime(now.year, now.month, 1);
          break;
      }
      return createdAt.isAfter(period) ? createdAt : period;
    }

    const colourMap = {
      GoalCategory.starCollection: 'orange',
      GoalCategory.activityCompletion: 'blue',
      GoalCategory.timeSpent: 'teal',
      GoalCategory.moodLogging: 'purple',
    };

    return goals.map((g) {
      final start = windowStart(g.duration, g.createdAt);
      int current;
      switch (g.category) {
        case GoalCategory.starCollection:
          // Stars are cumulative per profile — best signal we have is
          // total stars, capped at target so the bar fills cleanly.
          current = totalStars;
          break;
        case GoalCategory.activityCompletion:
          current = completions
              .where((c) => c.completedAt.isAfter(start))
              .length;
          break;
        case GoalCategory.timeSpent:
          final secs = completions
              .where((c) => c.completedAt.isAfter(start))
              .fold<int>(0, (sum, c) => sum + c.timeSpentSeconds);
          current = (secs / 60).round(); // target is in minutes
          break;
        case GoalCategory.moodLogging:
          current = journal.where((e) {
            final ts = DateTime.tryParse(e['timestamp'] as String? ?? '');
            return ts != null && ts.isAfter(start);
          }).length;
          break;
      }
      return <String, dynamic>{
        'id': g.id,
        'label':
            '${g.category.label} — ${g.category.unitLabel(g.target)}',
        'current': current,
        'target': g.target,
        'color': colourMap[g.category] ?? 'purple',
        'emoji': g.category.emoji,
      };
    }).toList();
  }

  String _timeAgo(String timestamp) {
    final date = DateTime.parse(timestamp).toLocal();
    final difference = DateTime.now().difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} mins ago';
    if (difference.inHours < 24) return '${difference.inHours} hours ago';
    return '${difference.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8FAFC),
              Color(0xFFEDE9FE),
            ],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Container(
                width: 320,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B21A8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withValues(alpha: 0.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      Center(
                        child: AnimatedBuilder(
                          animation: _glowCtrl,
                          builder: (context, _) {
                            final glow = 8.0 + _glowCtrl.value * 12.0;
                            return Text(
                              'EMOLOR',
                              style: GoogleFonts.fredoka(
                                fontSize: 61,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.white.withValues(
                                        alpha: 0.6 + _glowCtrl.value * 0.4),
                                    blurRadius: glow,
                                  ),
                                  Shadow(
                                    color: const Color(0xFFD8B4FE)
                                        .withValues(alpha: 0.5),
                                    blurRadius: glow + 4,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'ANALYTICS DASHBOARD',
                          style: _textStyle(
                              fontSize: 13,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNavItem(Icons.home_rounded, 'Home',
                                _selectedNavIndex == 0, () {
                              _loadRealData();
                              setState(() => _selectedNavIndex = 0);
                            }),
                            _buildNavItem(Icons.bar_chart_rounded, 'Progress',
                                _selectedNavIndex == 1, () {
                              setState(() => _selectedNavIndex = 1);
                            }),
                            _buildNavItem(Icons.emoji_events_rounded,
                                'Goals & Rewards', _selectedNavIndex == 2, () {
                              setState(() => _selectedNavIndex = 2);
                            }),
                            _buildNavItem(Icons.settings_rounded, 'Settings',
                                _selectedNavIndex == 3, () {
                              setState(() => _selectedNavIndex = 3);
                            }),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: InkWell(
                          onTap: () {
                            if (widget.showSwitchAccount) {
                              context.go('/child/home', extra: {
                                'showSwitch': true,
                                'childName': _childName,
                              });
                            } else {
                              context.go('/child-dashboard');
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626)
                                  .withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.red.shade300
                                      .withValues(alpha: 0.6)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.arrow_back_rounded,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text('Child Dashboard',
                                    style: GoogleFonts.baloo2(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _selectedNavIndex == 1
                    ? _buildProgressTab()
                    : _selectedNavIndex == 2
                        ? _buildGoalsRewardsTab()
                        : _selectedNavIndex == 3
                            ? _buildSettingsTab()
                            : _buildHomeTab(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _eColors = {
    'Happy': Color(0xFFFBBF24),
    'Sad': Color(0xFF60A5FA),
    'Angry': Color(0xFFEF4444),
    'Scared': Color(0xFF9B5DE5),
    'Excited': Color(0xFFF97316),
    'Calm': Color(0xFF14B8A6),
    'Surprised': Color(0xFFEC4899),
    'Disgusted': Color(0xFF78716C),
    'Joy': Color(0xFFFBBF24),
    'Trust': Color(0xFF22C55E),
    'Fear': Color(0xFF9B5DE5),
    'Anticipation': Color(0xFFF97316),
    'Sadness': Color(0xFF60A5FA),
    'Disgust': Color(0xFF78716C),
    'Anger': Color(0xFFEF4444),
    'Surprise': Color(0xFFEC4899),
    // Child-friendly emotion set
    'Loved': Color(0xFFEC4899),
    'Proud': Color(0xFF22C55E),
    'Shy': Color(0xFFF472B6),
    'Silly': Color(0xFFFBBF24),
    'Tired': Color(0xFF94A3B8),
    'Confused': Color(0xFF8B5CF6),
  };
  static const _eEmojis = {
    'Happy': '😄',
    'Sad': '😢',
    'Angry': '😡',
    'Scared': '😨',
    'Excited': '🤩',
    'Calm': '😌',
    'Surprised': '😲',
    'Disgusted': '🤢',
    'Joy': '😊',
    'Trust': '🤝',
    'Fear': '😨',
    'Anticipation': '🤩',
    'Sadness': '😢',
    'Disgust': '🤢',
    'Anger': '😡',
    'Surprise': '😲',
    // Child-friendly emotion set
    'Loved': '🥰',
    'Proud': '😤',
    'Shy': '🫣',
    'Silly': '🤪',
    'Tired': '😴',
    'Confused': '😕',
  };

  // ── Week selector helpers ────────────────────────────────────────

  /// Returns the Monday that starts the week at [offset]
  /// (0 = current week, -1 = last week, …).
  DateTime _weekStartDate(int offset) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final target = DateTime(monday.year, monday.month, monday.day)
        .add(Duration(days: 7 * offset));
    return target;
  }

  /// Week selector label in `DD/MM/YYYY – DD/MM/YYYY` format
  /// (Mon → Sun of the selected week). Only offsets 0, -1, -2 are
  /// valid (clamped at the InkWell level).
  String _weekLabel(int offset) {
    final start = _weekStartDate(offset);
    final end = start.add(const Duration(days: 6));
    String two(int n) => n.toString().padLeft(2, '0');
    String fmt(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';
    return '${fmt(start)} – ${fmt(end)}';
  }

  // ── Real / fake week metrics dispatcher ──────────────────────────
  //
  // CONDITIONAL LOADING:
  //   offset ==  0  →  REAL data (from Supabase + local services).
  //                   Filtered to current Mon-Sun window.
  //   offset == -1  →  FAKE data → const _kFakeWeeks[-1] ("Last Week")
  //   offset == -2  →  FAKE data → const _kFakeWeeks[-2] ("2 Weeks Ago")
  //
  // Real and fake data are NEVER mixed: either every metric is sourced
  // from the database or every metric is sourced from the static fake
  // dataset, depending on which week the user has selected.
  _WeekMetrics _metricsForWeek(int offset) {
    if (offset == 0) {
      return _realCurrentWeekMetrics();
    }
    return _kFakeWeeks[offset] ?? const _WeekMetrics();
  }

  /// Build a [_WeekMetrics] snapshot from the loaded real-data services.
  /// Only used when the selected week is "This Week" — we deliberately
  /// keep the real data path completely separate from the fake dataset
  /// so neither can leak into the other.
  _WeekMetrics _realCurrentWeekMetrics() {
    const positiveSet = _kPositiveEmotions;
    const negativeSet = _kNegativeEmotions;

    final weekStart = _weekStartDate(0);
    final weekEnd = weekStart.add(const Duration(days: 7));

    // Filter journal to current week.
    final weekJournal = _recentJournal.where((e) {
      final ts = DateTime.tryParse(e['timestamp'] as String? ?? '');
      return ts != null && ts.isAfter(weekStart) && ts.isBefore(weekEnd);
    }).toList();

    // Emotion frequency for the week.
    final Map<String, int> freq = {};
    for (final e in weekJournal) {
      final em = e['emotion'] as String? ?? '';
      if (em.isNotEmpty) freq[em] = (freq[em] ?? 0) + 1;
    }

    // Per-day positive / negative counts (Sun=0 … Sat=6).
    final positivePerDay = List<int>.filled(7, 0);
    final negativePerDay = List<int>.filled(7, 0);
    for (final entry in weekJournal) {
      final ts =
          DateTime.tryParse(entry['timestamp'] as String? ?? '')?.toLocal();
      if (ts == null) continue;
      final dayOfWeek = ts.weekday % 7; // Sun=0..Sat=6
      final em = entry['emotion'] as String? ?? '';
      if (positiveSet.contains(em)) {
        positivePerDay[dayOfWeek]++;
      } else if (negativeSet.contains(em)) {
        negativePerDay[dayOfWeek]++;
      }
    }

    // Filter completions to current week.
    final weekCompletions = _allCompletions
        .where((c) =>
            c.completedAt.isAfter(weekStart) &&
            c.completedAt.isBefore(weekEnd))
        .toList();

    // Sessions per day (Mon=0 … Sun=6 to match Engagement chart labels).
    final sessionsPerDay = List<int>.filled(7, 0);
    for (final c in weekCompletions) {
      final dow = c.completedAt.weekday; // Mon=1..Sun=7
      sessionsPerDay[dow - 1]++;
    }

    // Game minutes per activity.
    const validActivities = [
      'EMOZZLE', 'EMOPOP', 'EMOSPELL', 'EMOMATCH',
      'EMOSLASH', 'EMOCATCH', 'ANIMATCH', 'Draw',
    ];
    final Map<String, int> gameSecs = {};
    for (final c in weekCompletions) {
      if (!validActivities.contains(c.activityName)) continue;
      gameSecs[c.activityName] =
          (gameSecs[c.activityName] ?? 0) + c.timeSpentSeconds;
    }
    final gameMinutes = <String, int>{
      for (final e in gameSecs.entries) e.key: (e.value / 60).round(),
    };

    return _WeekMetrics(
      emotionFreq: freq,
      positivePerDay: positivePerDay,
      negativePerDay: negativePerDay,
      sessionsPerDay: sessionsPerDay,
      gameMinutes: gameMinutes,
    );
  }

  // ── AI insight: trim helper, prompt builder, generator ──────────
  //
  // For "This Week" we only want the AI to talk about days that have
  // actually happened — never claim about days from Wed–Sat if today
  // is Tuesday. We zero-out future-day slots in the per-day arrays
  // before building the prompt. emotionFreq / gameMinutes are already
  // safe because they only contain entries the child actually logged.
  _WeekMetrics _trimMetricsToToday(_WeekMetrics m) {
    final now = DateTime.now();
    final dowSun = now.weekday % 7; // Sun=0..Sat=6  (matches positivePerDay)
    final dowMon = now.weekday - 1; // Mon=0..Sun=6  (matches sessionsPerDay)
    return _WeekMetrics(
      emotionFreq: m.emotionFreq,
      positivePerDay: List.generate(
          7, (i) => i <= dowSun ? m.positivePerDay[i] : 0),
      negativePerDay: List.generate(
          7, (i) => i <= dowSun ? m.negativePerDay[i] : 0),
      sessionsPerDay: List.generate(
          7, (i) => i <= dowMon ? m.sessionsPerDay[i] : 0),
      gameMinutes: m.gameMinutes,
    );
  }

  /// Build the prompt sent to Claude. Only describes data that actually
  /// exists — empty days, zero-minute activities and unused emotions
  /// are filtered out so the model can't hallucinate them.
  String _buildAiPrompt(_WeekMetrics m, int offset) {
    final start = _weekStartDate(offset);
    final end = start.add(const Duration(days: 6));
    String two(int n) => n.toString().padLeft(2, '0');
    String fmt(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';

    const dayNamesSun = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final dayLines = <String>[];
    for (int i = 0; i < 7; i++) {
      final pos = m.positivePerDay[i];
      final neg = m.negativePerDay[i];
      if (pos == 0 && neg == 0) continue;
      dayLines.add(
          '  - ${dayNamesSun[i]}: $pos positive, $neg negative emotion entries');
    }

    final emotionLines = m.emotionFreq.entries
        .where((e) => e.value > 0)
        .map((e) => '  - ${e.key}: ${e.value} time(s)')
        .toList();

    final activityLines = m.gameMinutes.entries
        .where((e) => e.value > 0)
        .map((e) => '  - ${e.key}: ${e.value} min')
        .toList();

    final totalSessions =
        m.sessionsPerDay.fold<int>(0, (sum, v) => sum + v);

    final cutoffNote = offset == 0
        ? 'NOTE: Only days from Sunday up to TODAY (${fmt(DateTime.now())}) '
            'are listed. Do NOT mention any later days in the week.'
        : 'NOTE: This is the complete summary for the past week '
            '${fmt(start)} – ${fmt(end)}.';

    return '''
You are summarising one child's emotional + activity data for the parent.

Week range: ${fmt(start)} – ${fmt(end)}
$cutoffNote

EMOTION ENTRIES PER DAY:
${dayLines.isEmpty ? '  (no entries)' : dayLines.join('\n')}

EMOTION FREQUENCY (whole week so far):
${emotionLines.isEmpty ? '  (no entries)' : emotionLines.join('\n')}

ACTIVITY TIME (minutes spent on each game / activity):
${activityLines.isEmpty ? '  (no activity)' : activityLines.join('\n')}

TOTAL SESSIONS LOGGED: $totalSessions

Write 2–3 short, simple, parent-friendly, encouraging sentences that
summarise the week. Stick STRICTLY to the data above — do not invent
days, emotions, activities, goals or trends that are not listed. If a
mix of positive and negative emotions appears, acknowledge both
gently. Plain text only — no markdown, no headings, no emojis.
''';
  }

  /// Triggered by the "Generate Insight Summary" button. Pulls the
  /// metrics for the currently-selected week, short-circuits to a
  /// fixed message when the week is empty, otherwise calls Claude.
  Future<void> _generateAiInsight() async {
    if (_aiLoading) return;
    setState(() {
      _aiLoading = true;
      _aiError = null;
      _aiInsight = null;
    });

    try {
      // For "This Week" we only feed Sun → today.  Past weeks (fake
      // data) get the full snapshot.
      var metrics = _metricsForWeek(_selectedWeekOffset);
      if (_selectedWeekOffset == 0) {
        metrics = _trimMetricsToToday(metrics);
      }

      // Empty-data short-circuit — never burn an API call on a blank
      // week, and surface the exact copy the spec asks for.
      final hasAny = metrics.emotionFreq.values.any((v) => v > 0) ||
          metrics.gameMinutes.values.any((v) => v > 0) ||
          metrics.sessionsPerDay.any((v) => v > 0);
      if (!hasAny) {
        if (!mounted) return;
        setState(() {
          _aiInsight =
              'No data available yet. Start using EMOLOR this week to generate an insight summary.';
          _aiLoading = false;
        });
        return;
      }

      final prompt = _buildAiPrompt(metrics, _selectedWeekOffset);
      final summary = await AiInsightService.generateInsight(prompt);
      if (!mounted) return;
      setState(() {
        _aiInsight = summary;
        _aiLoading = false;
      });
    } catch (e) {
      debugPrint('AI insight error: $e');
      if (!mounted) return;
      setState(() {
        _aiError = 'Could not generate summary. Please try again.';
        _aiLoading = false;
      });
    }
  }

  /// The AI insight panel — sits at the bottom of the Progress tab
  /// after the four charts. Has four mutually-exclusive states:
  ///   • idle (no insight yet)  → placeholder text
  ///   • loading                → spinner
  ///   • error                  → red error chip
  ///   • success                → generated paragraph
  Widget _buildAiInsightSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF4FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF5D0FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology,
                  color: Color(0xFFC026D3), size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text('AI Insight Summary',
                    style: _textStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF86198F))),
              ),
              ElevatedButton.icon(
                onPressed: _aiLoading ? null : _generateAiInsight,
                icon: Icon(
                    _aiInsight == null
                        ? Icons.auto_awesome
                        : Icons.refresh_rounded,
                    color: Colors.white,
                    size: 18),
                label: Text(
                  _aiInsight == null
                      ? 'Generate Insight Summary'
                      : 'Regenerate',
                  style: _textStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC026D3),
                  disabledBackgroundColor: Colors.grey[300],
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Mutually-exclusive state slots ────────────────────────
          if (_aiLoading)
            Row(children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFFC026D3)),
              ),
              const SizedBox(width: 12),
              Text('Generating insight…',
                  style: _textStyle(
                      fontSize: 14, color: const Color(0xFF86198F))),
            ])
          else if (_aiError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(children: [
                Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_aiError!,
                      style: _textStyle(
                          fontSize: 13, color: Colors.red[700]!)),
                ),
              ]),
            )
          else if (_aiInsight != null)
            Text(
              _aiInsight!,
              style: _textStyle(
                      fontSize: 16,
                      color: const Color(0xFF4A044E),
                      fontWeight: FontWeight.w500)
                  .copyWith(height: 1.5),
            )
          else
            Text(
              'Click "Generate Insight Summary" to receive a parent-friendly '
              'recap of the selected week\'s analytics.',
              style: _textStyle(
                  fontSize: 14,
                  color: const Color(0xFF86198F).withValues(alpha: 0.7)),
            ),
        ],
      ),
    );
  }

  // ── Reusable week selector pill ──────────────────────────────────
  Widget _buildWeekSelector() {
    final atOldest = _selectedWeekOffset <= -2;
    final atNewest = _selectedWeekOffset >= 0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
            color: const Color(0xFF6B21A8).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ◀ prev (older) week
          InkWell(
            onTap: atOldest
                ? null
                : () => setState(() {
                      _selectedWeekOffset--;
                      _aiInsight = null;
                      _aiError = null;
                    }),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Icon(Icons.chevron_left_rounded,
                  color: atOldest
                      ? Colors.grey.shade300
                      : const Color(0xFF6B21A8),
                  size: 22),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              _weekLabel(_selectedWeekOffset),
              style: _textStyle(
                  fontSize: 13,
                  color: const Color(0xFF6B21A8),
                  fontWeight: FontWeight.w600),
            ),
          ),
          // ▶ next (newer) week — disabled on This Week
          InkWell(
            onTap: atNewest
                ? null
                : () => setState(() {
                      _selectedWeekOffset++;
                      _aiInsight = null;
                      _aiError = null;
                    }),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Icon(Icons.chevron_right_rounded,
                  color: atNewest
                      ? Colors.grey.shade300
                      : const Color(0xFF6B21A8),
                  size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    const positiveSet = _kPositiveEmotions;
    const negativeSet = _kNegativeEmotions;

    // Single source of truth for the selected week — switches between
    // real and fake data internally so this build method never has to
    // know which path produced the numbers.
    final metrics = _metricsForWeek(_selectedWeekOffset);
    final freq = metrics.emotionFreq;

    int posCount = 0;
    int negCount = 0;
    freq.forEach((emotion, count) {
      if (positiveSet.contains(emotion)) {
        posCount += count;
      } else if (negativeSet.contains(emotion)) {
        negCount += count;
      }
    });
    final totalPolarised = posCount + negCount;

    // Card 1 — Weekly Feelings
    String weeklyLabel;
    String weeklySub;
    Color weeklyColor;
    String weeklyEmoji;
    if (totalPolarised == 0) {
      weeklyLabel = 'No data';
      weeklySub = 'No entries this week';
      weeklyColor = Colors.grey;
      weeklyEmoji = '🌤️';
    } else if (posCount >= negCount) {
      final pct = ((posCount / totalPolarised) * 100).round();
      weeklyLabel = 'Mostly Positive';
      weeklySub = '$pct% positive';
      weeklyColor = const Color(0xFF10B981);
      weeklyEmoji = '🌞';
    } else {
      final pct = ((negCount / totalPolarised) * 100).round();
      weeklyLabel = 'Mostly Negative';
      weeklySub = '$pct% negative';
      weeklyColor = const Color(0xFFEF4444);
      weeklyEmoji = '🌧️';
    }

    // Card 2 — Most Played (from gameMinutes map directly).
    String mostPlayedGame = '—';
    String mostPlayedTime = '0 mins';
    if (metrics.gameMinutes.isNotEmpty) {
      final sorted = metrics.gameMinutes.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (sorted.first.value > 0) {
        mostPlayedGame = _brandedGameName(sorted.first.key);
        mostPlayedTime = '${sorted.first.value} mins';
      }
    }

    // Cards 3 & 4 — Frequent positive / negative
    MapEntry<String, int>? topPositive;
    MapEntry<String, int>? topNegative;
    freq.forEach((emotion, count) {
      if (positiveSet.contains(emotion)) {
        if (topPositive == null || count > topPositive!.value) {
          topPositive = MapEntry(emotion, count);
        }
      } else if (negativeSet.contains(emotion)) {
        if (topNegative == null || count > topNegative!.value) {
          topNegative = MapEntry(emotion, count);
        }
      }
    });

    final freqPosName = topPositive?.key ?? '—';
    final freqPosEmoji = _eEmojis[freqPosName] ?? '😊';
    final freqPosSub = topPositive != null
        ? '${topPositive!.value}×'
        : 'Not yet';

    final freqNegName = topNegative?.key ?? '—';
    final freqNegEmoji = _eEmojis[freqNegName] ?? '😔';
    final freqNegSub = topNegative != null
        ? '${topNegative!.value}×'
        : 'Not yet';

    // Card 5 — Emotion Variety
    final distinctEmotions = freq.keys
        .where((k) => positiveSet.contains(k) || negativeSet.contains(k))
        .length;

    // Card 6 — Top Mood Colour
    final dominantEmotion = posCount >= negCount ? topPositive : topNegative;
    final dominantName = dominantEmotion?.key ?? '—';
    final dominantColour = dominantEmotion != null
        ? EmotionColourMapping.colorFor(dominantName)
        : Colors.grey.shade400;

    final card1 = _buildHomeCard(
        weeklyEmoji, 'Weekly Feelings', weeklyLabel, weeklyColor, weeklySub);
    final card2 = _buildHomeCard(
        '🎮', 'Most Played', mostPlayedGame, Colors.amber, mostPlayedTime);
    final card3 = _buildHomeCard(freqPosEmoji, 'Frequent Positive',
        freqPosName, const Color(0xFF10B981), freqPosSub);
    final card4 = _buildHomeCard(freqNegEmoji, 'Frequent Negative',
        freqNegName, const Color(0xFFEF4444), freqNegSub);
    final card5 = _buildHomeCard(
        '🌈', 'Emotion Variety', '$distinctEmotions',
        const Color(0xFF8B5CF6),
        distinctEmotions == 1 ? 'emotion felt' : 'different emotions');
    final card6 = _buildHomeCard('🎨', 'Top Mood Colour', dominantName,
        dominantColour, 'Linked to My Colours');

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top bar: title + week selector + refresh ──────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  '$_childName\'s Weekly Overview',
                  style: _textStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF6B21A8)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              _buildWeekSelector(),
              const SizedBox(width: 10),
              // ── Refresh button — only meaningful for live data ────
              GestureDetector(
                onTap: () {
                  _loadRealData();
                  setState(() => _selectedWeekOffset = 0);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B21A8).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                        color:
                            const Color(0xFF6B21A8).withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.refresh_rounded,
                        color: Color(0xFF6B21A8), size: 22),
                    const SizedBox(width: 7),
                    Text('Refresh',
                        style: _textStyle(
                            fontSize: 15,
                            color: const Color(0xFF6B21A8))),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── 6 flashcards in 3 rows × 2 columns ───────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        card1,
                        const SizedBox(width: 12),
                        card2,
                      ]),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        card3,
                        const SizedBox(width: 12),
                        card4,
                      ]),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        card5,
                        const SizedBox(width: 12),
                        card6,
                      ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabHeader(
      String emoji, Color iconColor, String title, String subtitle,
      {Widget? action}) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFFEDE9FE),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF6B21A8), width: 2.5),
          ),
          child:
              Center(child: Text(emoji, style: const TextStyle(fontSize: 32))),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: _textStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF6B21A8))),
              Text(subtitle,
                  style: _textStyle(fontSize: 16, color: Colors.grey[500]!)),
            ],
          ),
        ),
        if (action != null) action,
      ],
    );
  }

  Widget _buildHomeCard(
      String emoji, String title, String value, Color color, String sub,
      {bool isInsight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 14,
                offset: const Offset(0, 5))
          ],
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 60))),
            ),
            const SizedBox(width: 32),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: _textStyle(fontSize: 22, color: Colors.grey[500]!),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1),
                  const SizedBox(height: 4),
                  Text(value,
                      style: _textStyle(
                              fontSize: isInsight ? 25 : 37,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF6B21A8))
                          .copyWith(height: 1.1),
                      overflow: TextOverflow.ellipsis,
                      maxLines: isInsight ? 2 : 1),
                  const SizedBox(height: 4),
                  Text(sub,
                      style: _textStyle(fontSize: 19, color: Colors.grey[400]!),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 3,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: _textStyle(
              fontSize: 13,
              color: Colors.grey[600]!,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildEmotionDetailChip(
      String emoji, String name, String pct, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 5),
          Text(
            name,
            style: _textStyle(
              fontSize: 12,
              color: Colors.grey[700]!,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            pct,
            style: _textStyle(
              fontSize: 12,
              color: Colors.grey[800]!,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionDistributionPanel({
    required Color accentColor,
    required Color backgroundColor,
    required String title,
    required String totalLabel,
    required List<PieChartSectionData> sections,
    required List<MapEntry<String, int>> emotions,
    required int total,
    required int touchedIndex,
    required void Function(int) onSectionTouched,
  }) {
    // Rebuild sections with touch-aware radius so the tapped slice
    // pops outward, and hide the % label when the name is overlaid.
    const double baseRadius = 60;
    const double touchRadius = 72;
    final touchSections = sections.asMap().entries.map((en) {
      final s = en.value;
      final isTouched = en.key == touchedIndex;
      return PieChartSectionData(
        value: s.value,
        color: s.color,
        title: isTouched ? '' : s.title,
        radius: isTouched ? touchRadius : baseRadius,
        titleStyle: s.titleStyle,
      );
    }).toList();

    // Name of the currently-touched slice (shown as overlay in pie centre).
    final String? touchedName =
        (touchedIndex >= 0 && touchedIndex < emotions.length)
            ? emotions[touchedIndex].key
            : null;
    final String? touchedEmoji = touchedName != null
        ? (_eEmojis[touchedName] ?? '')
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Pie chart with touch overlay showing emotion name.
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: touchSections,
                    sectionsSpace: 1,
                    centerSpaceRadius: 26,
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event,
                          PieTouchResponse? response) {
                        final idx = response
                                ?.touchedSection?.touchedSectionIndex ??
                            -1;
                        // Clear on lift/exit; set on press/hover.
                        if (event is FlTapUpEvent ||
                            event is FlPointerExitEvent ||
                            event is FlLongPressEnd) {
                          onSectionTouched(-1);
                        } else if (idx >= 0) {
                          onSectionTouched(idx);
                        }
                      },
                    ),
                  ),
                ),
                // Centre overlay: shows emoji + name when a slice is tapped.
                if (touchedName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(touchedEmoji ?? '',
                            style: const TextStyle(fontSize: 16)),
                        Text(
                          touchedName,
                          style: _textStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[800]!,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        title,
                        style: _textStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '·',
                        style: _textStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[500]!,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          totalLabel,
                          style: _textStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[700]!,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Chips show emoji + name + % for easy reading.
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: emotions.map((e) {
                      final pct = total > 0
                          ? ((e.value / total) * 100).toStringAsFixed(0)
                          : '0';
                      return _buildEmotionDetailChip(
                        _eEmojis[e.key] ?? '',
                        e.key,
                        '$pct%',
                        accentColor,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, String subtitle,
      {required double height, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 14,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: _textStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF6B21A8))),
          const SizedBox(height: 3),
          Text(subtitle,
              style: _textStyle(fontSize: 14, color: Colors.grey[500]!)),
          const SizedBox(height: 16),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }

  /// Wraps a chart [child] with a "No data yet" overlay when [hasData]
  /// is false. The chart is still rendered (faded out) so the layout
  /// stays consistent — a fresh profile sees a clear, friendly empty
  /// state rather than fictitious sample data.
  Widget _emptyChartOverlay({
    required bool hasData,
    required Widget child,
    String message = 'No data yet — start a session to see this chart.',
  }) {
    if (hasData) return child;
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: 0.25, child: IgnorePointer(child: child)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insights_outlined,
                  size: 18, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: _textStyle(
                      fontSize: 13,
                      color: const Color(0xFF6B7280),
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrePostChartUnused() {
    // REMOVED — replaced by 4-chart Progress tab layout.
    // Kept as dead code to avoid breaking the git diff history.
    final completeSessions = _childSessions
        .where((s) =>
            s['pre_emotion_name'] != null && s['post_emotion_name'] != null)
        .take(7)
        .toList()
        .reversed
        .toList();

    if (completeSessions.isEmpty) {
      // Show sample data so chart is always visible
      return _buildChartCard(
        '🔄 Emotion Shift',
        'How feelings changed after each session (last 7 sessions)',
        height: 220,
        child: Center(
          child: Text(
            'No session data yet.\nComplete a session to see shifts here!',
            textAlign: TextAlign.center,
            style: _textStyle(fontSize: 15, color: Colors.grey[500]!),
          ),
        ),
      );
    }

    // Build side-by-side bar groups: left=pre, right=post
    // Y-axis maps valence: positive=1, negative=-1 (shifted to 0..2 for chart)
    double valenceScore(String? valence) {
      if (valence == 'positive') return 2.0;
      if (valence == 'negative') return 0.5;
      return 1.25;
    }

    final barGroups = completeSessions.asMap().entries.map((entry) {
      final i = entry.key;
      final s = entry.value;
      final preColor = EmotionColourMapping.colorFor(
          s['pre_emotion_name'] as String? ?? 'Happy');
      final postColor = EmotionColourMapping.colorFor(
          s['post_emotion_name'] as String? ?? 'Happy');
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: valenceScore(s['pre_emotion_valence'] as String?),
            color: preColor,
            width: 18,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
          BarChartRodData(
            toY: valenceScore(s['post_emotion_valence'] as String?),
            color: postColor,
            width: 18,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
        barsSpace: 4,
      );
    }).toList();

    return _buildChartCard(
      '🔄 Emotion Shift',
      'How feelings changed after each session (last 7 sessions)',
      height: 240,
      child: Column(
        children: [
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Before', const Color(0xFF6B7280)),
              const SizedBox(width: 20),
              _buildLegendItem('After', const Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 2.5,
                minY: 0,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1F2937),
                    getTooltipItem: (group, _, rod, rodIndex) {
                      final s = completeSessions[group.x];
                      final emotionName = rodIndex == 0
                          ? s['pre_emotion_name'] as String? ?? '?'
                          : s['post_emotion_name'] as String? ?? '?';
                      final label = rodIndex == 0 ? 'Before' : 'After';
                      return BarTooltipItem(
                        '$label: $emotionName',
                        const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                      );
                    },
                  ),
                ),
                barGroups: barGroups,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                      color: Colors.grey.withValues(alpha: 0.15), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      getTitlesWidget: (v, _) {
                        if (v == 2.0) return Text('😊 +', style: _textStyle(fontSize: 11, color: Colors.grey[600]!));
                        if (v == 0.5) return Text('😔 −', style: _textStyle(fontSize: 11, color: Colors.grey[600]!));
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= completeSessions.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('S${idx + 1}',
                              style: _textStyle(fontSize: 12, color: Colors.grey[600]!)),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTab() {
    // The 7 games on the Play screen + the Draw activity. Both bar chart
    // (Activity Performance) and any other per-activity widget should
    // iterate in this order so the x-axis stays consistent.
    const coreGames = [
      'EMOZZLE',
      'EMOPOP',
      'EMOSPELL',
      'EMOMATCH',
      'EMOSLASH',
      'EMOCATCH',
      'ANIMATCH',
      'Draw',
    ];

    const positiveEmotions = _kPositiveEmotions;
    const negativeEmotions = _kNegativeEmotions;

    // ── Single source of truth for all 4 charts ─────────────────────
    // Real for "This Week", static fake data for "Last Week" / "2 Weeks
    // Ago". Real and fake data are produced by separate code paths
    // inside _metricsForWeek and never combined.
    final metrics = _metricsForWeek(_selectedWeekOffset);

    final List<int> positivePerDay = metrics.positivePerDay;
    final List<int> negativePerDay = metrics.negativePerDay;

    // Per-emotion frequency derived from the metrics (so the chart's
    // distribution slices stay aligned with the trend totals).
    final Map<String, int> positiveFreqRecent = {};
    final Map<String, int> negativeFreqRecent = {};
    metrics.emotionFreq.forEach((em, count) {
      if (positiveEmotions.contains(em)) {
        positiveFreqRecent[em] = count;
      } else if (negativeEmotions.contains(em)) {
        negativeFreqRecent[em] = count;
      }
    });

    // Distribution panel lists (aligned with trend totals).
    final positiveEmotionsData = positiveFreqRecent.entries.toList();
    final negativeEmotionsData = negativeFreqRecent.entries.toList();

    // Totals derived from the same perDay sums shown in the trend chart.
    final totalPositive = positivePerDay.reduce((a, b) => a + b);
    final totalNegative = negativePerDay.reduce((a, b) => a + b);

    // Pie sections — each slice gets a unique index-based colour so no
    // two slices ever share the same colour (avoids the duplicate-colour
    // bug that occurred when different emotion names had the same entry
    // in _eColors).
    const double _pieRadius = 60;
    const TextStyle _pieLabelStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      shadows: [Shadow(color: Colors.black38, blurRadius: 2)],
    );


    final pieSectionsPositive = positiveEmotionsData.asMap().entries.map((en) {
      final e = en.value;
      final value = e.value.toDouble();
      final color = EmotionColourMapping.colorFor(e.key);
      final percentage = totalPositive > 0
          ? ((value / totalPositive) * 100).toStringAsFixed(0)
          : '0';
      return PieChartSectionData(
        value: value, color: color, title: '$percentage%',
        radius: _pieRadius, titleStyle: _pieLabelStyle,
      );
    }).toList();

    final pieSectionsNegative = negativeEmotionsData.asMap().entries.map((en) {
      final e = en.value;
      final value = e.value.toDouble();
      final color = EmotionColourMapping.colorFor(e.key);
      final percentage = totalNegative > 0
          ? ((value / totalNegative) * 100).toStringAsFixed(0)
          : '0';
      return PieChartSectionData(
        value: value, color: color, title: '$percentage%',
        radius: _pieRadius, titleStyle: _pieLabelStyle,
      );
    }).toList();

    if (pieSectionsPositive.isEmpty) {
      pieSectionsPositive.add(PieChartSectionData(
          value: 1, color: const Color(0xFF10B981), title: '0%',
          radius: _pieRadius, titleStyle: _pieLabelStyle));
    }
    if (pieSectionsNegative.isEmpty) {
      pieSectionsNegative.add(PieChartSectionData(
          value: 1, color: const Color(0xFFEF4444), title: '0%',
          radius: _pieRadius, titleStyle: _pieLabelStyle));
    }

    // Create line chart data for positive and negative emotions. Dots
    // on every day + a soft fill beneath each line echo the Engagement
    // Trend chart's style.
    final emotionLineBars = [
      LineChartBarData(
        spots: List.generate(
            7, (day) => FlSpot(day.toDouble(), positivePerDay[day].toDouble())),
        color: const Color(0xFF10B981), // Green for positive
        barWidth: 3,
        isCurved: true,
        curveSmoothness: 0.3,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(
          show: true,
          color: const Color(0xFF10B981).withValues(alpha: 0.18),
        ),
      ),
      LineChartBarData(
        spots: List.generate(
            7, (day) => FlSpot(day.toDouble(), negativePerDay[day].toDouble())),
        color: const Color(0xFFEF4444), // Red for negative
        barWidth: 3,
        isCurved: true,
        curveSmoothness: 0.3,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(
          show: true,
          color: const Color(0xFFEF4444).withValues(alpha: 0.18),
        ),
      ),
    ];

    final maxEmotionValue = max(
      positivePerDay.reduce(max),
      negativePerDay.reduce(max),
    ).toDouble();
    // Flexible Y-axis — follow the actual data. If the busiest day hits
    // 1, the axis tops at 1; if it hits 4, the axis tops at 4, etc.
    // Minimum of 1 so a totally-empty week still renders with a tick.
    final double maxEmotionY =
        maxEmotionValue < 1 ? 1.0 : maxEmotionValue.ceilToDouble();

    // Minutes spent per activity over the selected week, aligned to the
    // coreGames order so x-axis labels line up with the bars.
    List<double> barMinutes = coreGames
        .map((g) => (metrics.gameMinutes[g] ?? 0).toDouble())
        .toList();
    // Y-axis headroom: round up to the nearest 5 minutes above the peak
    // so the tallest bar never hugs the top.
    final double peakMinutes = barMinutes.reduce(max);
    final double barsMaxY = peakMinutes <= 5
        ? 5.0
        : (((peakMinutes + 4) ~/ 5) * 5).toDouble();

    // Sessions per day for Engagement Trend chart, sourced from the same
    // metrics object so the chart respects the week selector.
    final List<int> engagementData = metrics.sessionsPerDay;
    final maxEngagement = engagementData.reduce(max).toDouble() + 1;

    final engagementLineBar = LineChartBarData(
      spots: List.generate(
          7, (i) => FlSpot(i.toDouble(), engagementData[i].toDouble())),
      color: Colors.blueAccent,
      barWidth: 3,
      isCurved: true,
      dotData: const FlDotData(show: true),
      belowBarData: BarAreaData(
          show: true, color: Colors.blueAccent.withValues(alpha: 0.2)),
    );

    // Empty-state flags — used below to overlay a "No data yet" message
    // on each chart instead of showing a flat / empty plot. We do NOT
    // hide the chart container itself so the layout stays stable.
    final bool hasEmotionData = totalPositive > 0 || totalNegative > 0;
    final bool hasGameMinutes = barMinutes.any((m) => m > 0);
    final bool hasEngagementData = engagementData.any((c) => c > 0);

    return Column(
      children: [
        Container(
          color: const Color(0xFFF9FAFB),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: _buildTabHeader(
              '📊',
              const Color(0xFF6B21A8),
              'Progress Dashboard',
              'Emotion trends, game performance & weekly activity',
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Same week selector as the Home tab — drives all 4 charts.
                  _buildWeekSelector(),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf,
                        color: Colors.white, size: 18),
                    label: Text('Export Report',
                        style: _textStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B21A8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Generating PDF Report...')));

                      // PDF export always reports on real all-time data,
                      // never the fake-data preview.
                      String topE = _emotionFreq.isNotEmpty
                          ? (_emotionFreq.entries.toList()
                                ..sort((a, b) => b.value.compareTo(a.value)))
                              .first
                              .key
                          : 'Happy';
                      String summaryInsight =
                          'The child demonstrated a predominantly positive emotional pattern, with $topE being the most frequently expressed emotion. Engagement remained consistent with gradual improvement seen in the latest sessions.';

                      await PdfReportService.generateReport(
                        childName: _childName,
                        summaryInsight: summaryInsight,
                        emotionFreq: _emotionFreq,
                        gameAvgStars: _gameAvgStars,
                      );
                    },
                  ),
                ],
              )),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              children: [
                _buildChartCard(
                  '📈 Emotion Trend',
                  'Positive vs Negative emotions throughout the week',
                  height: 260,
                  // Extra top padding keeps the plotted lines clear of the
                  // subtitle — they used to sit right underneath it.
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _emptyChartOverlay(
                            hasData: hasEmotionData,
                            message: 'No emotion entries yet this week.',
                            child: LineChart(
                            LineChartData(
                              minX: 0,
                              maxX: 6,
                              lineBarsData: emotionLineBars,
                              minY: 0,
                              maxY: maxEmotionY,
                              lineTouchData: LineTouchData(
                                handleBuiltInTouches: true,
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipColor: (_) =>
                                      const Color(0xFF1F2937),
                                  fitInsideHorizontally: true,
                                  fitInsideVertically: true,
                                  getTooltipItems: (spots) => spots.map((spot) {
                                    final label = spot.barIndex == 0
                                        ? 'Positive'
                                        : 'Negative';
                                    return LineTooltipItem(
                                      '$label: ${spot.y.toInt()}',
                                      const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              titlesData: FlTitlesData(
                                // Hide the Y-axis scale entirely — the tap
                                // tooltip already reveals exact counts, and
                                // Engagement Trend uses the same no-label
                                // treatment.
                                leftTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 30,
                                    interval: 1,
                                    getTitlesWidget: (v, _) {
                                      const days = [
                                        'Sun',
                                        'Mon',
                                        'Tue',
                                        'Wed',
                                        'Thu',
                                        'Fri',
                                        'Sat'
                                      ];

                                      if (v < 0 || v > 6 || v != v.roundToDouble()) {
                                        return const SizedBox.shrink();
                                      }

                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          days[v.toInt()],
                                          style: _textStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600]!,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              // Same horizontal-line treatment as the
                              // Engagement Trend chart: thin grey lines at
                              // every default tick, no vertical gridlines.
                              gridData: FlGridData(
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (_) => FlLine(
                                  color: Colors.grey.withValues(alpha: 0.15),
                                  strokeWidth: 1,
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                            ),
                          ),
                          ), // _emptyChartOverlay
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Legend column — sits at the top-right corner of the
                      // chart card, clear of the plotted lines.
                      SizedBox(
                        width: 86,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            _buildLegendItem(
                                'Positive', const Color(0xFF10B981)),
                            const SizedBox(height: 10),
                            _buildLegendItem(
                                'Negative', const Color(0xFFEF4444)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildChartCard(
                  '🥧 Emotion Distribution',
                  'Percentage share of positive vs negative emotions',
                  height: 250,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildEmotionDistributionPanel(
                          accentColor: const Color(0xFF10B981),
                          backgroundColor: const Color(0xFFE6F7EE),
                          title: 'Positive',
                          totalLabel: totalPositive > 0
                              ? '$totalPositive times'
                              : '0 times',
                          sections: pieSectionsPositive,
                          emotions: positiveEmotionsData,
                          total: totalPositive,
                          touchedIndex: _touchedPositiveSection,
                          onSectionTouched: (i) =>
                              setState(() => _touchedPositiveSection = i),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildEmotionDistributionPanel(
                          accentColor: const Color(0xFFEF4444),
                          backgroundColor: const Color(0xFFFEE2E2),
                          title: 'Negative',
                          totalLabel: totalNegative > 0
                              ? '$totalNegative times'
                              : '0 times',
                          sections: pieSectionsNegative,
                          emotions: negativeEmotionsData,
                          total: totalNegative,
                          touchedIndex: _touchedNegativeSection,
                          onSectionTouched: (i) =>
                              setState(() => _touchedNegativeSection = i),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _buildChartCard(
                  '🎮 Activity Performance',
                  'Minutes spent per activity this week',
                  height: 240,
                  child: _emptyChartOverlay(
                    hasData: hasGameMinutes,
                    message: 'No activity time logged this week.',
                    child: BarChart(BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: barsMaxY,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => const Color(0xFF1F2937),
                        getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                          '${_brandedGameName(coreGames[group.x.toInt()])}\n'
                          '${rod.toY.toInt()} min',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    barGroups: barMinutes
                        .asMap()
                        .entries
                        .map((e) => BarChartGroupData(
                              x: e.key,
                              barRods: [
                                BarChartRodData(
                                  toY: e.value,
                                  color: const Color(0xFF14B8A6),
                                  width: 18,
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(6)),
                                ),
                              ],
                            ))
                        .toList(),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(
                            color: Colors.grey.withValues(alpha: 0.15),
                            strokeWidth: 1)),
                    titlesData: FlTitlesData(
                      // Left axis hidden — minutes are revealed via the
                      // tap tooltip so the chart stays clean regardless
                      // of how large the values get.
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      // Bottom axis — full branded name under every bar.
                      bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= coreGames.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _brandedGameName(coreGames[idx]),
                              style: _textStyle(
                                fontSize: 12,
                                color: Colors.grey[700]!,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      )),
                    ),
                  )), // BarChart(BarChartData)
                  ), // _emptyChartOverlay
                ),
                const SizedBox(height: 14),
                _buildChartCard(
                  '⏱️ Engagement Trend',
                  'Sessions per day identifying interest peaks and drops',
                  height: 200,
                  child: _emptyChartOverlay(
                    hasData: hasEngagementData,
                    message: 'No sessions yet this week.',
                    child: LineChart(LineChartData(
                    lineBarsData: [engagementLineBar],
                    minY: 0,
                    maxY: maxEngagement,
                    lineTouchData: LineTouchData(
                      handleBuiltInTouches: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => const Color(0xFF1F2937),
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItems: (spots) => spots.map((spot) {
                          final count = spot.y.toInt();
                          final label =
                              count == 1 ? '1 session' : '$count sessions';
                          return LineTooltipItem(
                            label,
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        // Pin the tick interval to whole days so fl_chart
                        // doesn't auto-generate fractional x-values (which
                        // were producing duplicate day labels like
                        // "Mon Mon Tue Tue …").
                        interval: 1,
                        getTitlesWidget: (v, _) {
                          const labels = [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun'
                          ];
                          if (v < 0 || v > 6 || v != v.roundToDouble()) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              labels[v.toInt()],
                              style: _textStyle(
                                  fontSize: 13, color: Colors.grey[600]!),
                            ),
                          );
                        },
                      )),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(
                            color: Colors.grey.withValues(alpha: 0.15),
                            strokeWidth: 1)),
                  )), // LineChart(LineChartData)
                  ), // _emptyChartOverlay
                ),
                const SizedBox(height: 14),
                // ── On-demand AI Insight Summary ─────────────────────
                _buildAiInsightSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPill(String emoji, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: _textStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            Text(label,
                style: _textStyle(fontSize: 12, color: Colors.grey[600]!)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildInsightRow(
      String emoji, String label, String value, Color color) {
    return Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 8),
      Expanded(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: _textStyle(fontSize: 12, color: Colors.grey[500]!)),
          Text(value,
              style: _textStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: color),
              overflow: TextOverflow.ellipsis),
        ],
      )),
    ]);
  }

  Widget _buildScoreRow(String emoji, String label, int score, Color color) {
    return Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 8),
      Expanded(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label,
                style: _textStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text('$score/100',
                style: _textStyle(
                    fontSize: 13, color: color, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          Stack(children: [
            Container(
                height: 8,
                decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4))),
            FractionallySizedBox(
                widthFactor: score / 100,
                child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(4)))),
          ]),
        ],
      )),
    ]);
  }

  Widget _buildNavItem(
      IconData icon, String label, bool isActive, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                label,
                style: _textStyle(
                  fontSize: 22,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderButton(IconData icon, String badge) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 10,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.grey[700], size: 30),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
            child: Text(
              badge,
              style: _textStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String emoji, String title, String value, Color color, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 10),
            Text(value,
                style: _textStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: _textStyle(
                          fontSize: 18,
                          color: Colors.grey[700]!,
                          fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: _textStyle(
                          fontSize: 15,
                          color: color,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, IconData icon, Widget child,
      {Color? titleColor}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF6B21A8), size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: _textStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: titleColor ?? Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Flexible(
            child: SingleChildScrollView(child: child),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
      String emoji, String title, String time, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        _textStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                Text(time,
                    style: _textStyle(fontSize: 15, color: Colors.grey[500]!)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityGrid(List<Widget> items) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      rows.add(Row(
        children: [
          Expanded(child: items[i]),
          const SizedBox(width: 10),
          if (i + 1 < items.length)
            Expanded(child: items[i + 1])
          else
            const Expanded(child: SizedBox()),
        ],
      ));
      if (i + 2 < items.length) rows.add(const SizedBox(height: 10));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  Widget _buildEmotionBar(String emotion, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(emotion,
                  style: _textStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              Text('${(value * 100).toInt()}%',
                  style: _textStyle(
                      fontSize: 18, color: color, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              FractionallySizedBox(
                widthFactor: value,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStat(String emoji, String value) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 30)),
        const SizedBox(height: 6),
        Text(value,
            style: _textStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildQuickAction(String emoji, String label, Color color,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Text(label,
                style: _textStyle(
                    fontSize: 18, color: color, fontWeight: FontWeight.w600)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  // Used by (now-dead) _buildInteractivePaletteCard
  static const List<Map<String, String>> _emotionList = [
    {'name': 'Joy', 'emoji': '😊'},
    {'name': 'Trust', 'emoji': '🤝'},
    {'name': 'Fear', 'emoji': '😨'},
    {'name': 'Surprise', 'emoji': '😲'},
    {'name': 'Sadness', 'emoji': '😢'},
    {'name': 'Disgust', 'emoji': '🤢'},
    {'name': 'Anger', 'emoji': '😡'},
    {'name': 'Anticipation', 'emoji': '🤩'},
  ];

  // ── Goals & Rewards Tab ────────────────────────────────────────────

  Widget _buildGoalsRewardsTab() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with Create Goal button
          _buildTabHeader(
            '🏆',
            const Color(0xFF22C55E),
            'Goals & Rewards',
            "Set targets and track your child's reward progress",
            action: ElevatedButton.icon(
              onPressed: () async {
                final saved = await NewGoalDialog.show(context);
                if (saved == true) {
                  // Pull fresh list with real progress values (and the
                  // `id` field, which the previous mapping dropped — that
                  // was why the X delete button silently no-op'd on
                  // newly-created goals).
                  final fresh = await _activeGoalsWithProgress();
                  if (mounted) {
                    setState(() => _activeGoals = fresh);
                  }
                }
              },
              icon: const Icon(Icons.add_circle_outline, size: 24),
              label: Text('Create New Goal',
                  style: _textStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B21A8),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Main content fills remaining space
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: Active Goals
                Expanded(
                  flex: 1,
                  child: _buildCard(
                    'Active Goals',
                    Icons.flag_rounded,
                    Builder(
                      builder: (context) {
                        if (_activeGoals.isEmpty) {
                          return Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 100),
                            child: Text('No active goals — create one!',
                                style: _textStyle(
                                    fontSize: 16, color: Colors.grey[400]!)),
                          );
                        }
                        final colorMap = {
                          'orange': Colors.orange,
                          'blue': Colors.blue,
                          'green': Colors.green,
                          'purple': Colors.purple,
                          'red': Colors.red,
                          'teal': Colors.teal,
                        };
                        return Column(
                          children: _activeGoals.asMap().entries.map((entry) {
                            final i = entry.key;
                            final g = entry.value;
                            final current = (g['current'] as int?) ?? 0;
                            final target = (g['target'] as int?) ?? 1;
                            final progress =
                                target > 0 ? current / target : 0.0;
                            final color = colorMap[g['color']] ?? Colors.blue;
                            return _buildGoalRow(
                              g['label'] as String,
                              progress.clamp(0.0, 1.0),
                              '$current/$target',
                              color,
                              g['emoji'] as String,
                              onRemove: () async {
                                final goalId = g['id'] as String?;
                                if (goalId != null) {
                                  await GoalService.deleteGoal(goalId);
                                }
                                if (mounted) {
                                  setState(() => _activeGoals.removeAt(i));
                                }
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),
                    titleColor: const Color(0xFF6B21A8),
                  ),
                ),

                const SizedBox(width: 16),

                // Right: Earned Rewards — real data
                Expanded(
                  flex: 1,
                  child: _buildCard(
                    'Earned Rewards',
                    Icons.emoji_events_rounded,
                    FutureBuilder<List<ChildReward>>(
                      future: ChildRewardsService.getUnlockedRewards(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        // Show ONLY rewards the child has actually earned.
                        // Previous behaviour padded the grid with locked
                        // teasers so a freshly-reset profile still showed
                        // four "reward" tiles, contradicting the real
                        // earned-stars state.
                        final display = snapshot.data!
                            .where((r) => r.unlockedAt != null)
                            .toList()
                          ..sort((a, b) =>
                              b.unlockedAt!.compareTo(a.unlockedAt!));

                        if (display.isEmpty) {
                          return Container(
                              alignment: Alignment.center,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 100),
                              child: Text(
                                  'No rewards yet — earn stars to unlock!',
                                  textAlign: TextAlign.center,
                                  style: _textStyle(
                                      fontSize: 16,
                                      color: Colors.grey[400]!)));
                        }

                        final rows = <Widget>[];
                        for (int i = 0; i < display.length; i += 2) {
                          rows.add(Row(
                            children: [
                              Expanded(
                                  child: _buildRewardChip(
                                      display[i].emoji,
                                      display[i].title,
                                      display[i].unlockedAt != null)),
                              const SizedBox(width: 14),
                              if (i + 1 < display.length)
                                Expanded(
                                    child: _buildRewardChip(
                                        display[i + 1].emoji,
                                        display[i + 1].title,
                                        display[i + 1].unlockedAt != null))
                              else
                                const Expanded(child: SizedBox()),
                            ],
                          ));
                          if (i + 2 < display.length)
                            rows.add(const SizedBox(height: 14));
                        }
                        return Column(children: rows);
                      },
                    ),
                    titleColor: const Color(0xFF6B21A8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalRow(String label, double progress, String progressText,
      Color color, String emoji,
      {Future<void> Function()? onRemove}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(label,
                          style: _textStyle(
                              fontSize: 20, fontWeight: FontWeight.w600)),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(progressText,
                            style: _textStyle(
                                fontSize: 20,
                                color: color,
                                fontWeight: FontWeight.w700)),
                        if (onRemove != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  title: Text('Remove Goal?',
                                      style: _textStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700)),
                                  content: Text(
                                      'Are you sure you want to remove this goal?',
                                      style: _textStyle(
                                          fontSize: 16,
                                          color: Colors.grey[700]!)),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: Text('Cancel',
                                          style: _textStyle(
                                              fontSize: 16,
                                              color: Colors.grey)),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                      child: Text('Remove',
                                          style: _textStyle(
                                              fontSize: 16,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) await onRemove!();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.red, size: 18),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardChip(String emoji, String label, bool earned) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: earned ? const Color(0xFFFFF3E0) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: earned ? Colors.orange.shade300 : Colors.grey.shade300,
            width: 2),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        _textStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                Text(earned ? 'Earned ✓' : 'Locked',
                    style: _textStyle(
                        fontSize: 13,
                        color: earned ? Colors.green : Colors.grey[400]!,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── My Child Tab — REMOVED ───────────────────────────────────────
  // Tab removed per UCD refactor (2026-04). Navigation index 3 is now Settings.

  Widget _buildMyChildTab_REMOVED() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTabHeader('👶', const Color(0xFFFF8A65), 'My Child',
              "View Thanesh's superpowers, insights, and interactive colours"),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // LEFT Column: Hero Profile Card
                SizedBox(
                  width: 320,
                  child: _buildHeroProfileCard(),
                ),

                const SizedBox(width: 18),

                // RIGHT Column
                Expanded(
                  child: Column(
                    children: [
                      // Top Right: Caregiver AI Insights
                      Expanded(
                        flex: 5,
                        child: _buildInsightsCard(),
                      ),

                      const SizedBox(height: 12),

                      // Bottom Right: Interactive Palette
                      Expanded(
                        flex: 6,
                        child: _buildInteractivePaletteCard(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 1. Hero Profile Card ──
  Widget _buildHeroProfileCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6B21A8), Color(0xFFC026D3), Color(0xFFEC4899)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC026D3).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with glowing ring
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [
                  Colors.yellow,
                  Colors.orange,
                  Colors.pink,
                  Colors.yellow
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(_childAvatar, style: const TextStyle(fontSize: 60)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            _childName.isEmpty ? 'Thanesh' : _childName,
            style: _textStyle(
                fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          Text(
            '🌟 Emotional Explorer Level 4',
            style: _textStyle(
                fontSize: 16, color: Colors.white.withValues(alpha: 0.8)),
          ),

          const SizedBox(height: 32),

          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildHeroStat(
                  '🔥', 'Streak', '${_totalActivities > 0 ? 3 : 0} Days'),
              Container(
                  width: 2,
                  height: 40,
                  color: Colors.white.withValues(alpha: 0.2)),
              _buildHeroStat('🏆', 'Badges', '2 Earned'),
              Container(
                  width: 2,
                  height: 40,
                  color: Colors.white.withValues(alpha: 0.2)),
              _buildHeroStat('🎮', 'Played', '$_totalActivities'),
            ],
          ),

          const Spacer(),

          // Recent Milestone
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recent Spark!',
                          style: _textStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600)),
                      Text(
                        'Learned to identify "Surprise" yesterday',
                        style: _textStyle(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHeroStat(String emoji, String label, String value) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(value,
            style: _textStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        Text(label, style: _textStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }

  // ── 2. AI Parenting Insights ──
  Widget _buildInsightsCard() {
    String topEmotion = _emotionFreq.isNotEmpty
        ? (_emotionFreq.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key
        : 'Happy';
    String rawFavGame = _gameFreq.isNotEmpty
        ? (_gameFreq.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key
        : 'EMOZZLE';
    String favGame = _brandedGameName(rawFavGame);

    String superpower = topEmotion == 'Happy'
        ? 'Radiating Joy & Focus'
        : topEmotion == 'Calm'
            ? 'Deep Zen & Concentration'
            : topEmotion == 'Excited'
                ? 'High Energy Curiosity'
                : 'Empathy & Deep Feeling';

    String focus =
        'Learning to recognize subtle emotions like surprise and fear.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Graphic
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.auto_awesome,
                color: Color(0xFF3B82F6), size: 48),
          ),
          const SizedBox(width: 20),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Caregiver Insights',
                    style: _textStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('🦸‍♂️ ', style: TextStyle(fontSize: 18)),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: _textStyle(
                              fontSize: 16, color: const Color(0xFF475569)),
                          children: [
                            const TextSpan(
                                text: 'Emotional Superpower: ',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            TextSpan(text: superpower),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('🎯 ', style: TextStyle(fontSize: 18)),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: _textStyle(
                              fontSize: 16, color: const Color(0xFF475569)),
                          children: [
                            const TextSpan(
                                text: 'Current Focus: ',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            TextSpan(text: focus),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF4FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF5D0FE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          color: Color(0xFFC026D3), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Tip: Since they love $favGame, offer a small reward next time they complete it!",
                          style: _textStyle(
                              fontSize: 14,
                              color: const Color(0xFF86198F),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Interactive Palette ──
  Widget _buildInteractivePaletteCard() {
    return FutureBuilder<void>(
      future: EmotionColourMapping.ensureLoaded(),
      builder: (context, snapshot) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.08),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.palette,
                          color: Color(0xFF14B8A6), size: 26),
                      const SizedBox(width: 8),
                      Text("Emotional Palette",
                          style: _textStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E293B))),
                    ],
                  ),
                  Text("Tap cards for tips ✨",
                      style: _textStyle(
                          fontSize: 14,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _emotionList.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final e = _emotionList[index];
                    final color = EmotionColourMapping.colorFor(e['name']!);
                    final tip = _getTipForEmotion(e['name']!);
                    return _InteractiveEmotionCard(
                      emoji: e['emoji']!,
                      name: e['name']!,
                      color: color,
                      tip: tip,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getTipForEmotion(String emotion) {
    switch (emotion) {
      case 'Happy':
        return 'Great time to try new, challenging games!';
      case 'Sad':
        return 'Offer a comforting hug and ask open ended questions.';
      case 'Angry':
        return 'Give 5 minutes of quiet time to cool down.';
      case 'Calm':
        return 'Perfect state for focused learning activities.';
      case 'Surprised':
        return 'Explore new topics while curiosity is high!';
      case 'Fear':
        return 'Reassure safety and do a breathing exercise.';
      case 'Love':
        return 'Reinforce positive bonds with a shared activity.';
      case 'Bored':
        return 'Mix things up with a high-energy game!';
      default:
        return 'Listen and validate their feelings without judgment.';
    }
  }

  Widget _buildJournalChip(String emoji, String emotion, String game) {
    final color = EmotionColourMapping.colorFor(emotion);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 6),
          Text(emotion,
              style: _textStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(width: 5),
          Text('· $game',
              style: _textStyle(
                  fontSize: 14,
                  color: Colors.grey[500]!,
                  fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }

  // ── Settings Tab ─────────────────────────────────────────────────

  // ── Settings Tab ─────────────────────────────────────────────────

  // ── Notification toggle states ──
  bool _messageAlerts = true;
  bool _rewardAlerts = true;
  bool _sessionReminders = false;

  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTabHeader('⚙️', const Color(0xFF3B82F6), 'Settings',
              'Manage your account, security and preferences'),
          const SizedBox(height: 20),
          Expanded(
            child: Column(
              children: [
                // Account & Security side by side
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildCard(
                          'Account',
                          Icons.person_outline,
                          Column(
                            children: [
                              _buildSettingsRow(Icons.edit, 'Edit Profile',
                                  'Update your name and avatar',
                                  onTap: () => _showEditProfileDialog()),
                              const Divider(height: 1),
                              _buildSettingsRow(
                                  Icons.lock_outline,
                                  'Change Password',
                                  'Update your login password',
                                  onTap: () => _showChangePasswordDialog()),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildCard(
                          'Notifications',
                          Icons.notifications_outlined,
                          Column(
                            children: [
                              _buildToggleRow(
                                  Icons.flag_outlined,
                                  'Goal Alerts',
                                  'Time & star goal notifications',
                                  _messageAlerts, (v) {
                                setState(() => _messageAlerts = v);
                              }),
                              const Divider(height: 1),
                              _buildToggleRow(
                                  Icons.emoji_events_outlined,
                                  'Reward Alerts',
                                  'When child earns a reward',
                                  _rewardAlerts, (v) {
                                setState(() => _rewardAlerts = v);
                              }),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Security & Account Management
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildCard(
                          'Security',
                          Icons.shield_outlined,
                          Column(
                            children: [
                              _buildSettingsRow(Icons.pin, 'Parent Gate PIN',
                                  'Set or change your 4-digit PIN',
                                  onTap: () => _showParentPinDialog()),
                              const Divider(height: 1),
                              _buildSettingsRow(
                                  Icons.fingerprint,
                                  'Biometric Lock',
                                  'Use fingerprint to access caregiver settings',
                                  onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Biometric lock coming soon!')),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildCard(
                          'Account Management',
                          Icons.manage_accounts_rounded,
                          Column(
                            children: [
                              _buildSettingsRow(Icons.logout, 'Log Out',
                                  'Sign out of your account',
                                  onTap: () => _showLogoutConfirmDialog()),
                              const Divider(height: 1),
                              _buildSettingsRow(
                                  Icons.refresh_rounded,
                                  'Reset Game Data',
                                  'Reset stars, rewards & analytics to zero',
                                  iconColor: Colors.orange,
                                  onTap: () => _showResetGameDialog()),
                              const Divider(height: 1),
                              _buildSettingsRow(
                                  Icons.delete_forever,
                                  'Deactivate Account',
                                  'Permanently deactivate your account',
                                  iconColor: Colors.red,
                                  onTap: () => _showDeactivateConfirmDialog()),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsRow(IconData icon, String title, String subtitle,
      {VoidCallback? onTap, Color? iconColor}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? const Color(0xFF6B21A8), size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: _textStyle(
                          fontSize: 19, fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: _textStyle(
                          fontSize: 15,
                          color: Colors.grey[500]!,
                          fontWeight: FontWeight.w400)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow(IconData icon, String title, String subtitle,
      bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6B21A8), size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        _textStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: _textStyle(
                        fontSize: 15,
                        color: Colors.grey[500]!,
                        fontWeight: FontWeight.w400)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFF6B21A8),
          ),
        ],
      ),
    );
  }

  // ── Settings Dialogs ──────────────────────────────────────────────

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(
        text: _childName.isEmpty ? 'Thanesh' : _childName);
    final ageCtrl = TextEditingController(text: '7');
    final emailCtrl = TextEditingController(
        text: Supabase.instance.client.auth.currentUser?.email ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit Profile',
            style: _textStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFFA855F7)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                      child: Text(_childAvatar,
                          style: const TextStyle(fontSize: 40))),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Display Name',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Age',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: _textStyle(fontSize: 16, color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              setState(() => _childName = nameCtrl.text);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated!')));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B21A8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: Text('Save',
                style: _textStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Change Password',
            style: _textStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: TextEditingController(text: '12345678'),
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: _textStyle(fontSize: 16, color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password updated!')));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B21A8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: Text('Save',
                style: _textStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showResetGameDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 28),
            const SizedBox(width: 10),
            Text('Reset Game Data',
                style: _textStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange)),
          ],
        ),
        content: Text(
            'This will reset all stars, rewards, activities and emotion journal entries back to zero.\n\nThis action cannot be undone. Are you sure?',
            style: _textStyle(fontSize: 17, color: Colors.grey[700]!)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: _textStyle(fontSize: 16, color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await StarService.resetAll();
                await ChildRewardsService.resetAll();
                await CompletionService.clearAll();
                await EmotionJournalService.clearAll();
                await GoalService.clearAll();
              } catch (_) {}
              if (mounted) {
                _loadRealData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Game data has been reset to zero.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Reset',
                style: _textStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showParentPinDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Parent Gate PIN',
            style: _textStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 350,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Update your 4-digit PIN to protect caregiver settings',
                    style: _textStyle(fontSize: 16, color: Colors.grey[600]!)),
                const SizedBox(height: 16),
                TextField(
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: _textStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  controller: TextEditingController(text: '1234'),
                  decoration: InputDecoration(
                    labelText: 'Current PIN',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: _textStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: '• • • •',
                    labelText: 'New PIN',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: _textStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: '• • • •',
                    labelText: 'Confirm New PIN',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    counterText: '',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: _textStyle(fontSize: 16, color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('PIN saved!')));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B21A8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: Text('Save PIN',
                style: _textStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Log Out',
            style: _textStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to sign out?',
            style: _textStyle(fontSize: 18, color: Colors.grey[700]!)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: _textStyle(fontSize: 16, color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Supabase.instance.client.auth.signOut();
              if (mounted) context.go('/login');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: Text('Log Out',
                style: _textStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showDeactivateConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Text('Deactivate Account',
                style: _textStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.red)),
          ],
        ),
        content: Text(
            'This will permanently deactivate your account and erase your data. This action cannot be undone.\n\nAre you sure you want to proceed?',
            style: _textStyle(fontSize: 17, color: Colors.grey[700]!)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: _textStyle(fontSize: 16, color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Delete user profile from Supabase
              try {
                final userId = Supabase.instance.client.auth.currentUser?.id;
                if (userId != null) {
                  await Supabase.instance.client
                      .from('profiles')
                      .delete()
                      .eq('id', userId);
                }
                await Supabase.instance.client.auth.signOut();
              } catch (_) {}
              if (mounted) context.go('/login');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: Text('Deactivate',
                style: _textStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _InteractiveEmotionCard extends StatefulWidget {
  final String emoji;
  final String name;
  final Color color;
  final String tip;

  const _InteractiveEmotionCard({
    required this.emoji,
    required this.name,
    required this.color,
    required this.tip,
  });

  @override
  State<_InteractiveEmotionCard> createState() =>
      _InteractiveEmotionCardState();
}

class _InteractiveEmotionCardState extends State<_InteractiveEmotionCard> {
  bool _isFlipped = false;

  void _toggleFlip() {
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.color.computeLuminance() < 0.4;
    final textColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: _toggleFlip,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, animation) {
          final rotateAnim = Tween(begin: 3.14, end: 0.0).animate(animation);
          return AnimatedBuilder(
            animation: rotateAnim,
            child: child,
            builder: (context, child) {
              final angle = child!.key == const ValueKey('front')
                  ? rotateAnim.value
                  : -rotateAnim.value;
              return Transform(
                transform: Matrix4.rotationY(angle),
                alignment: Alignment.center,
                child: child,
              );
            },
          );
        },
        child: _isFlipped ? _buildBack(textColor) : _buildFront(textColor),
      ),
    );
  }

  Widget _buildFront(Color textColor) {
    return Container(
      key: const ValueKey('front'),
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: widget.color.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(widget.emoji, style: const TextStyle(fontSize: 42)),
          const SizedBox(height: 12),
          Text(
            widget.name,
            style: GoogleFonts.fredoka(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text('Tap for tip',
              style: TextStyle(
                  fontSize: 10,
                  color: textColor.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildBack(Color textColor) {
    return Container(
      key: const ValueKey('back'),
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: widget.color.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          widget.tip,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textColor,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ─── Mixed real/fake week-data system ─────────────────────────────────
//
// The Home tab and the Progress Dashboard's 4 charts both consume a
// single [_WeekMetrics] object. The dispatcher
// `_AnalyticsDashboardState._metricsForWeek(offset)` decides which
// source to use:
//
//    offset ==  0   →  REAL data (Supabase + local services), filtered
//                       to the current Mon-Sun window.
//    offset == -1   →  FAKE data → `_kFakeWeeks[-1]`  ("Last Week")
//    offset == -2   →  FAKE data → `_kFakeWeeks[-2]`  ("2 Weeks Ago")
//
// CRITICAL: real and fake data are never combined. `_WeekMetrics` is
// produced wholesale by exactly one path. When the user picks "Last
// Week" or "2 Weeks Ago" the live database isn't queried at all — we
// just hand back the const fake snapshot. When they pick "This Week"
// the fake snapshot is never consulted.
//
// The fake snapshots are *static* (compile-time `const` literals) so
// they don't change between app launches or refreshes — caregivers
// see the same demonstration data every time, which is exactly what
// the brief required ("Keep static (not random every refresh)").
// ──────────────────────────────────────────────────────────────────

/// Emotion names that count as "positive" — used by both Home cards
/// and Progress charts. Hoisted to a top-level const so the home tab
/// and progress tab can share it without duplicating string literals.
const Set<String> _kPositiveEmotions = {
  // Child-friendly set
  'Happy', 'Excited', 'Calm', 'Loved', 'Proud', 'Shy', 'Silly',
  // Plutchik / legacy names — kept for backward-compat
  'Joy', 'Trust', 'Anticipation', 'Surprise', 'Surprised', 'Love',
};

const Set<String> _kNegativeEmotions = {
  // Child-friendly set
  'Sad', 'Angry', 'Scared', 'Tired', 'Confused',
  // Plutchik / legacy names
  'Disgusted', 'Fear', 'Sadness', 'Disgust', 'Anger',
};

/// All numbers that drive a single week's worth of charts.
///
///   • [emotionFreq]    name → count, used by Home cards + Distribution
///   • [positivePerDay] index 0=Sun … 6=Sat (matches Emotion Trend chart)
///   • [negativePerDay] index 0=Sun … 6=Sat
///   • [sessionsPerDay] index 0=Mon … 6=Sun (matches Engagement chart)
///   • [gameMinutes]    raw activity id → minutes (for Activity bars +
///                      "Most Played" Home card)
///
/// All four lists default to `[0,0,0,0,0,0,0]` and the maps default to
/// empty so a missing offset still renders a clean empty state.
class _WeekMetrics {
  final Map<String, int> emotionFreq;
  final List<int> positivePerDay;
  final List<int> negativePerDay;
  final List<int> sessionsPerDay;
  final Map<String, int> gameMinutes;

  const _WeekMetrics({
    this.emotionFreq = const {},
    this.positivePerDay = const [0, 0, 0, 0, 0, 0, 0],
    this.negativePerDay = const [0, 0, 0, 0, 0, 0, 0],
    this.sessionsPerDay = const [0, 0, 0, 0, 0, 0, 0],
    this.gameMinutes = const {},
  });
}

/// Static, hand-curated demo data for the two preview weeks.
/// These never mutate at runtime and never read from the database.
const Map<int, _WeekMetrics> _kFakeWeeks = {
  // ── -1 = Last Week — a generally upbeat week ───────────────────────
  -1: _WeekMetrics(
    emotionFreq: {
      'Happy': 8,
      'Calm': 6,
      'Excited': 4,
      'Proud': 3,
      'Sad': 2,
      'Angry': 1,
      'Confused': 1,
    },
    // Sun, Mon, Tue, Wed, Thu, Fri, Sat
    positivePerDay: [3, 4, 2, 3, 5, 4, 0],
    negativePerDay: [0, 1, 1, 0, 0, 1, 1],
    // Mon, Tue, Wed, Thu, Fri, Sat, Sun
    sessionsPerDay: [3, 2, 4, 3, 5, 2, 0],
    gameMinutes: {
      'EMOZZLE': 35,
      'EMOPOP': 22,
      'EMOSPELL': 18,
      'EMOMATCH': 14,
      'EMOSLASH': 8,
      'EMOCATCH': 12,
      'ANIMATCH': 10,
      'Draw': 16,
    },
  ),
  // ── -2 = 2 Weeks Ago — a more challenging week ─────────────────────
  -2: _WeekMetrics(
    emotionFreq: {
      'Happy': 5,
      'Calm': 4,
      'Excited': 2,
      'Sad': 3,
      'Angry': 4,
      'Tired': 2,
      'Confused': 2,
    },
    positivePerDay: [1, 2, 2, 1, 3, 2, 0],
    negativePerDay: [2, 1, 2, 1, 1, 2, 2],
    sessionsPerDay: [2, 3, 1, 2, 3, 2, 1],
    gameMinutes: {
      'EMOZZLE': 18,
      'EMOPOP': 28,
      'EMOSPELL': 8,
      'EMOMATCH': 6,
      'EMOSLASH': 4,
      'EMOCATCH': 0,
      'ANIMATCH': 12,
      'Draw': 8,
    },
  ),
};
