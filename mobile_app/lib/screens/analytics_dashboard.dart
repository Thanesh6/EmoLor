import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/ai_insight_service.dart';
import '../core/services/auth_service.dart';
import '../core/services/emotion_colour_mapping.dart';
import '../core/constants/sensory_palette.dart';
import '../core/services/emotion_journal_service.dart';
import '../core/services/star_service.dart';
import '../features/caregiver/presentation/widgets/new_goal_dialog.dart';
import '../features/caregiver/services/goal_service.dart';
import '../features/caregiver/services/weekly_pdf_report_service.dart';
import '../features/child/services/child_rewards_service.dart';
import '../features/child/services/child_session_service.dart';
import '../features/child/services/completion_service.dart';
import '../features/child/models/completion_record.dart';

class AnalyticsDashboard extends StatefulWidget {
  final String? childName;
  final bool showSwitchAccount;

  /// When true the dashboard was opened via the caregiver shortcut on the
  /// profile-selection page.  No session is started; back returns the
  /// caregiver to "Who's Playing Today?" instead of the child dashboard.
  final bool caregiverShortcut;

  /// When provided, [profileId] is written to SharedPreferences BEFORE the
  /// first [_loadRealData] call so that [CompletionService] reads the correct
  /// child's bucket.  Without this, there is a race condition: the router
  /// builder fires [saveChildProfileId] as a fire-and-forget Future, but
  /// [initState] → [_loadRealData] can run before that write completes,
  /// causing the service to fall back to `completion_records_no_profile`.
  final String? profileId;

  const AnalyticsDashboard({
    super.key,
    this.childName,
    this.showSwitchAccount = false,
    this.caregiverShortcut = false,
    this.profileId,
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
  int? _childAge; // computed from profiles.date_of_birth

  // ── PDF generation (Progress tab) ──
  bool _pdfGenerating = false;

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
  // Keyed by week offset so switching weeks preserves already-generated
  // summaries.  0 = this week, -1 = last week, -2 = two weeks ago.
  final Map<int, String> _aiInsightByWeek = {};
  bool _aiLoading = false;
  String? _aiError;
  static const String _aiInsightPrefPrefix = 'ai_insight_week_';

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
    _loadPersistedAiInsights();

    // If a profileId was passed in (caregiver shortcut), write it to
    // SharedPreferences first so CompletionService, StarService, etc. all
    // scope to the correct child bucket.  Only then load the dashboard data.
    if (widget.profileId != null) {
      ChildSessionService.saveChildProfileId(widget.profileId!)
          .then((_) => _loadRealData());
    } else {
      _loadRealData();
    }
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
      final childSessions =
          await ChildSessionService.getRecentSessions(limit: 200);

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
      // 7 games from the Play screen + Color Memory + Draw activity.
      const validActivities = [
        'EMOZZLE',
        'EMOPOP',
        'EMOSPELL',
        'EMOMATCH',
        'EMOSLASH',
        'EMOCATCH',
        'ANIMATCH',
        'Color Memory Tiles',
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
            for (final e in gameTime7Days.entries)
              e.key: (e.value / 60).round(),
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
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Resolve target user_id to load profile for, in priority order:
      String? targetUserId;

      // 1. Caregiver shortcut explicitly passes profileId
      if (widget.profileId != null && widget.profileId!.isNotEmpty) {
        targetUserId = widget.profileId;
      }

      // 2. Active child session (PIN-gated kid using parent's account)
      if (targetUserId == null) {
        try {
          final sessionId = await ChildSessionService.getChildProfileId();
          if (sessionId != null && sessionId.isNotEmpty) {
            targetUserId = sessionId;
          }
        } catch (_) {}
      }

      // 3. Match family_links by name when childName was provided
      if (targetUserId == null) {
        final childName = widget.childName ?? _childName;
        if (childName.isNotEmpty && childName != 'Child') {
          try {
            final rows = await Supabase.instance.client
                .from('family_links')
                .select(
                    'child_id, profiles!family_links_child_id_fkey(user_id, full_name, avatar_url, date_of_birth)')
                .eq('caregiver_id', userId);
            if (rows is List) {
              for (final r in rows) {
                final p = r['profiles'] as Map<String, dynamic>?;
                if (p != null && (p['full_name'] as String?) == childName) {
                  targetUserId = p['user_id'] as String?;
                  break;
                }
              }
            }
          } catch (_) {}
        }
      }

      // 4. First linked child via family_links (single-child caregivers)
      if (targetUserId == null) {
        try {
          final links = await Supabase.instance.client
              .from('family_links')
              .select('child_id')
              .eq('caregiver_id', userId)
              .limit(1);
          if (links is List && links.isNotEmpty) {
            targetUserId = links.first['child_id'] as String?;
          }
        } catch (_) {}
      }

      // 5. RPC fallback by name
      if (targetUserId == null) {
        final childName = widget.childName ?? _childName;
        if (childName.isNotEmpty && childName != 'Child') {
          try {
            final profiles = await Supabase.instance.client.rpc(
                'get_child_profile_by_name',
                params: {'p_name': childName});
            if (profiles is List && profiles.isNotEmpty) {
              final profile = profiles.first as Map<String, dynamic>;
              targetUserId = profile['user_id']?.toString();
            }
          } catch (_) {}
        }
      }

      // 6. Final fallback: the currently signed-in user
      targetUserId ??= userId;
      debugPrint('LOADCHILD targetUserId=$targetUserId');

      Map<String, dynamic>? profile;
      try {
        final rows = await Supabase.instance.client
            .from('profiles')
            .select('user_id, full_name, avatar_url, date_of_birth')
            .or('user_id.eq.$targetUserId,profile_id.eq.$targetUserId')
            .limit(1);
        debugPrint('LOADCHILD direct rows=${(rows as List).length}');
        if (rows.isNotEmpty) profile = rows.first as Map<String, dynamic>;
      } catch (e) {
        debugPrint('LOADCHILD direct read error: $e');
      }

// RLS fallback: direct read blocked/empty → resolve via the SECURITY
// DEFINER RPC that bypasses RLS (same pattern as get_child_profile_by_name).
      if (profile == null) {
        final childName = widget.childName ?? _childName;
        if (childName.isNotEmpty && childName != 'Child') {
          try {
            final res = await Supabase.instance.client.rpc(
                'get_child_profile_by_name',
                params: {'p_name': childName});
            debugPrint('LOADCHILD rpc result=$res');
            if (res is List && res.isNotEmpty) {
              profile = res.first as Map<String, dynamic>;
            }
          } catch (e) {
            debugPrint('LOADCHILD rpc error: $e');
          }
        }
      }

      if (mounted && profile != null) {
        setState(() {
          _childUserId = profile!['user_id'] as String?;
          final name = profile!['full_name'] as String?;
          if (name != null && name.isNotEmpty) _childName = name;
          final av = profile!['avatar_url'] as String?;
          if (av != null && av.isNotEmpty) _childAvatar = av;
          _computeAge(profile!['date_of_birth'] as String?);
        });
      }
      debugPrint('LOADCHILD final _childUserId=$_childUserId');
    } catch (e) {
      debugPrint('Error loading child profile: $e');
    }
  }

  void _computeAge(String? dobStr) {
    if (dobStr == null || dobStr.isEmpty) return;
    try {
      final dob = DateTime.parse(dobStr);
      final now = DateTime.now();
      int years = now.year - dob.year;
      if (now.month < dob.month ||
          (now.month == dob.month && now.day < dob.day)) years--;
      _childAge = years >= 0 ? years : null;
    } catch (e) {}
  }

  Future<void> _loadPersistedAiInsights() async {
    final prefs = await SharedPreferences.getInstance();
    for (int offset = -2; offset <= 0; offset++) {
      final key = '$_aiInsightPrefPrefix$offset';
      final saved = prefs.getString(key);
      if (saved != null && saved.isNotEmpty) {
        setState(() => _aiInsightByWeek[offset] = saved);
      }
    }
  }

  Future<void> _saveAiInsight(int weekOffset, String summary) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_aiInsightPrefPrefix$weekOffset', summary);
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
      case 'Color Memory Tiles':
        return 'Color Memory';
      case 'Draw':
        return 'Draw';
      default:
        if (rawName.isEmpty) return rawName;
        return rawName[0].toUpperCase() + rawName.substring(1).toLowerCase();
    }
  }

  /// Build the active-goals list with **real** progress values.
  ///
  /// Delegates the math to `GoalService.liveCurrentForGoal` so the
  /// caregiver dashboard and analytics dashboard share one definition
  /// of progress. Goals created mid-window count from their createdAt
  /// instead of the window start, which is handled inside the service.
  Future<List<Map<String, dynamic>>> _activeGoalsWithProgress() async {
    final goals = await GoalService.getAllGoals();
    if (goals.isEmpty) return [];

    final completions = await CompletionService.history();
    final journal = await EmotionJournalService.getEntries();
    final totalStars = await StarService.getTotalStars();

    const colourMap = {
      GoalCategory.starCollection: 'orange',
      GoalCategory.activityCompletion: 'blue',
      GoalCategory.timeSpent: 'teal',
      GoalCategory.moodLogging: 'purple',
    };

    return goals.map((g) {
      final current = GoalService.liveCurrentForGoal(
        g,
        totalStars: totalStars,
        completions: completions,
        journal: journal,
      );
      return <String, dynamic>{
        'id': g.id,
        'label': '${g.category.label} — ${g.category.unitLabel(g.target)}',
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
                              _loadRealData();
                              setState(() => _selectedNavIndex = 1);
                            }),
                            _buildNavItem(Icons.emoji_events_rounded, 'Rewards',
                                _selectedNavIndex == 2, () {
                              _loadRealData();
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
                            if (widget.caregiverShortcut) {
                              context.go('/orgz-child-dashboard');
                            } else if (widget.showSwitchAccount) {
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
                            padding: EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: widget.caregiverShortcut ? 10 : 14),
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
                                const SizedBox(width: 6),
                                Text(
                                    widget.caregiverShortcut
                                        ? 'Return to Profile Selection'
                                        : 'Child Dashboard',
                                    style: GoogleFonts.baloo2(
                                        fontSize:
                                            widget.caregiverShortcut ? 14 : 16,
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

  /// Week selector label in `DD/MM/YYYY – DD/MM/YYYY` format.
  /// Used by the PDF builder (keeps the existing plain-text format).
  String _weekLabel(int offset) {
    final start = _weekStartDate(offset);
    final end = start.add(const Duration(days: 6));
    String two(int n) => n.toString().padLeft(2, '0');
    String fmt(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';
    return '${fmt(start)} – ${fmt(end)}';
  }

  /// Formats a [DateTime] as "Mon 27 Apr" for the calendar-style selector.
  String _calendarDateFmt(DateTime d) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${dayNames[d.weekday - 1]} ${d.day} ${monthNames[d.month - 1]}';
  }

  /// Human-readable date range for the calendar selector.
  /// Format: "Mon 27 Apr – Sun 3 May"
  String _weekDateRange(int offset) {
    final start = _weekStartDate(offset);
    final end = start.add(const Duration(days: 6));
    return '${_calendarDateFmt(start)} – ${_calendarDateFmt(end)}';
  }

  /// Short label for a week offset.
  String _weekOffsetLabel(int offset) {
    final start = _weekStartDate(offset);
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[start.month]} ${start.year}';
  }

  /// Opens the week-picker dialog.  Only three weeks are selectable:
  ///   0  = This Week  (real data)
  ///  -1  = Last Week  (sample data)
  ///  -2  = 2 Weeks Ago (sample data)
  void _showWeekPickerDialog() {
// Earliest selectable month — January 2026
    const firstMonth = (year: 2026, month: 1);
    final now = DateTime.now();

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) {
        // Start calendar on the month of the currently selected week
        final selectedWeekStart = _weekStartDate(_selectedWeekOffset);
        int displayYear = selectedWeekStart.year;
        int displayMonth = selectedWeekStart.month;

        // Current week start for offset calculation
        final currentWeekStart = _weekStartDate(0);

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final bool canGoBack = displayYear > firstMonth.year ||
                (displayYear == firstMonth.year &&
                    displayMonth > firstMonth.month);
            final bool canGoForward = displayYear < now.year ||
                (displayYear == now.year && displayMonth < now.month);

            // Build list of week-start dates in the displayed month
            // A week starts on Monday. We include a week if ANY day of
            // that week falls within the displayed month AND the week
            // start is not in the future.
            final List<DateTime> weeksInMonth = [];
            // Find first Monday on or before the 1st of the month
            final firstOfMonth = DateTime(displayYear, displayMonth, 1);
            int dayOffset = firstOfMonth.weekday - 1; // Mon=0
            DateTime weekCursor =
                firstOfMonth.subtract(Duration(days: dayOffset));

            while (true) {
              // Week belongs to this month if its Monday OR any day is in month
              final weekEnd = weekCursor.add(const Duration(days: 6));
              if (weekCursor.month > displayMonth &&
                  weekCursor.year >= displayYear) break;
              if (weekEnd.month < displayMonth && weekEnd.year <= displayYear) {
                weekCursor = weekCursor.add(const Duration(days: 7));
                continue;
              }
              // Don't show future weeks
              if (!weekCursor.isAfter(currentWeekStart)) {
                weeksInMonth.add(weekCursor);
              }
              weekCursor = weekCursor.add(const Duration(days: 7));
              if (weekCursor.year > displayYear ||
                  (weekCursor.year == displayYear &&
                      weekCursor.month > displayMonth)) break;
            }

            String fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/'
                '${d.month.toString().padLeft(2, '0')}';

            const monthNames = [
              '',
              'January',
              'February',
              'March',
              'April',
              'May',
              'June',
              'July',
              'August',
              'September',
              'October',
              'November',
              'December'
            ];

            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.calendar_month_rounded,
                            color: Color(0xFF7C3AED), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text('Select Week',
                          style: _textStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF6B21A8))),
                    ]),
                    const SizedBox(height: 20),

                    // ── Month navigation ─────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: canGoBack
                              ? () {
                                  setDialogState(() {
                                    if (displayMonth == 1) {
                                      displayMonth = 12;
                                      displayYear--;
                                    } else {
                                      displayMonth--;
                                    }
                                  });
                                }
                              : null,
                          icon: Icon(Icons.chevron_left_rounded,
                              color: canGoBack
                                  ? const Color(0xFF6B21A8)
                                  : Colors.grey.shade300,
                              size: 28),
                        ),
                        Text(
                          '${monthNames[displayMonth]} $displayYear',
                          style: _textStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF6B21A8)),
                        ),
                        IconButton(
                          onPressed: canGoForward
                              ? () {
                                  setDialogState(() {
                                    if (displayMonth == 12) {
                                      displayMonth = 1;
                                      displayYear++;
                                    } else {
                                      displayMonth++;
                                    }
                                  });
                                }
                              : null,
                          icon: Icon(Icons.chevron_right_rounded,
                              color: canGoForward
                                  ? const Color(0xFF6B21A8)
                                  : Colors.grey.shade300,
                              size: 28),
                        ),
                      ],
                    ),

                    // ── Day headers ──────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children:
                            ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                                .map((d) => Expanded(
                                      child: Center(
                                        child: Text(d,
                                            style: _textStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.grey.shade500)),
                                      ),
                                    ))
                                .toList(),
                      ),
                    ),

                    const Divider(height: 1),
                    const SizedBox(height: 8),

                    // ── Week rows ────────────────────────────────────
                    if (weeksInMonth.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text('No data available for this month',
                              style: _textStyle(
                                  fontSize: 14, color: Colors.grey.shade400)),
                        ),
                      )
                    else
                      ...weeksInMonth.map((weekStart) {
                        // Compute offset from current week
                        final diffDays =
                            currentWeekStart.difference(weekStart).inDays;
                        final offset = -(diffDays ~/ 7);
                        final isSelected = _selectedWeekOffset == offset;
                        final isCurrentWeek = offset == 0;

                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedWeekOffset = offset);
                            Navigator.pop(ctx);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF6B21A8)
                                  : isCurrentWeek
                                      ? const Color(0xFFF3E8FF)
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: isCurrentWeek && !isSelected
                                  ? Border.all(
                                      color: const Color(0xFFD8B4FE),
                                      width: 1.5)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                // Day numbers for the week
                                ...List.generate(7, (i) {
                                  final day = weekStart.add(Duration(days: i));
                                  final inMonth = day.month == displayMonth;
                                  final isToday = day.year == now.year &&
                                      day.month == now.month &&
                                      day.day == now.day;
                                  return Expanded(
                                    child: Center(
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: isToday && !isSelected
                                            ? BoxDecoration(
                                                color: const Color(0xFF6B21A8),
                                                shape: BoxShape.circle,
                                              )
                                            : null,
                                        child: Center(
                                          child: Text(
                                            '${day.day}',
                                            style: _textStyle(
                                              fontSize: 14,
                                              fontWeight: isSelected || isToday
                                                  ? FontWeight.w800
                                                  : FontWeight.w500,
                                              color: isSelected
                                                  ? Colors.white
                                                  : isToday
                                                      ? Colors.white
                                                      : inMonth
                                                          ? const Color(
                                                              0xFF1F2937)
                                                          : Colors
                                                              .grey.shade400,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                // Current week badge only
                                if (isCurrentWeek)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.25)
                                          : const Color(0xFF6B21A8)
                                              .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Now',
                                      style: _textStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF6B21A8),
                                      ),
                                    ),
                                  )
                                else
                                  const SizedBox(width: 6),
                              ],
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// One selectable row inside the week-picker dialog.
  Widget _buildWeekPickerRow(BuildContext ctx, int offset) {
    final isSelected = offset == _selectedWeekOffset;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedWeekOffset = offset;
          _aiError = null;
        });
        Navigator.of(ctx).pop();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF3E8FF) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF7C3AED) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _weekOffsetLabel(offset),
                  style: _textStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? const Color(0xFF6B21A8)
                          : Colors.grey.shade700),
                ),
                const SizedBox(height: 3),
                Text(
                  _weekDateRange(offset),
                  style: _textStyle(
                      fontSize: 13,
                      color: isSelected
                          ? const Color(0xFF9333EA)
                          : Colors.grey.shade500),
                ),
              ],
            ),
          ),
          if (isSelected)
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF7C3AED), size: 22)
          else
            Icon(Icons.radio_button_unchecked_rounded,
                color: Colors.grey.shade300, size: 22),
        ]),
      ),
    );
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
    return _realMetricsForWeek(offset);
  }

  /// Build a [_WeekMetrics] snapshot from the loaded real-data services.
  /// Only used when the selected week is "This Week" — we deliberately
  /// keep the real data path completely separate from the fake dataset
  /// so neither can leak into the other.
  ///
  /// IMPORTANT: every field here is computed from data the current child
  /// profile actually saved. We never inject placeholder numbers for
  /// "This Week" — an empty week stays empty, which is exactly what the
  /// flashcards/charts need to show a clean zero/empty state.
  _WeekMetrics _realMetricsForWeek(int offset) {
    const positiveSet = _kPositiveEmotions;
    const negativeSet = _kNegativeEmotions;

    final weekStart = _weekStartDate(offset);
    final weekEnd = weekStart.add(const Duration(days: 7));

    // ── Emotion journal (in-game emoji interactions) ──────────────
    final weekJournal = _recentJournal.where((e) {
      final ts = DateTime.tryParse(e['timestamp'] as String? ?? '');
      return ts != null && ts.isAfter(weekStart) && ts.isBefore(weekEnd);
    }).toList();

    final Map<String, int> freq = {};
    for (final e in weekJournal) {
      final em = e['emotion'] as String? ?? '';
      if (em.isNotEmpty) freq[em] = (freq[em] ?? 0) + 1;
    }

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

    // ── Completions (game finishes) ───────────────────────────────
    final weekCompletions = _allCompletions
        .where((c) =>
            c.completedAt.isAfter(weekStart) && c.completedAt.isBefore(weekEnd))
        .toList();
    debugPrint('weekCompletions count: ${weekCompletions.length}');
    for (final c in weekCompletions) {
      debugPrint(
          'completion: ${c.activityName} | ${c.timeSpentSeconds}s | ${c.starsEarned} stars | ${c.completedAt}');
    }
    debugPrint('allCompletions total: ${_allCompletions.length}');

    final sessionsPerDay = List<int>.filled(7, 0);
    for (final c in weekCompletions) {
      final dow = c.completedAt.weekday; // Mon=1..Sun=7
      sessionsPerDay[dow - 1]++;
    }

    const validActivities = [
      'EMOZZLE',
      'EMOPOP',
      'EMOSPELL',
      'EMOMATCH',
      'EMOSLASH',
      'EMOCATCH',
      'ANIMATCH',
      'Color Memory Tiles',
      'Draw',
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

    // Stars earned this week (sum across all in-week completions).
    final int starsEarned =
        weekCompletions.fold<int>(0, (sum, c) => sum + c.starsEarned);

    // ── Pre / Post session emotions (Supabase child_sessions) ─────
    //
    // Active-session rule: only sessions that have been *fully saved*
    // count. A session row is created when the child picks the pre
    // emotion, but `post_emotion_name` only lands when they finish
    // the post-feel screen — so any in-flight session shows up with
    // a null post and is excluded from post counts and from the
    // "Total Sessions" tile.
    final weekSessions = _childSessions.where((s) {
      final ts = DateTime.tryParse(s['session_date'] as String? ?? '');
      return ts != null && ts.isAfter(weekStart) && ts.isBefore(weekEnd);
    }).toList();

    final Map<String, int> preFreq = {};
    final Map<String, int> postFreq = {};
    final prePerDay = List<int>.filled(7, 0);
    final postPerDay = List<int>.filled(7, 0);
    // Pre/post split by sentiment so the trend chart can stack positive
    // (green) on top of negative (red) per session phase.
    final prePositivePerDay = List<int>.filled(7, 0);
    final preNegativePerDay = List<int>.filled(7, 0);
    final postPositivePerDay = List<int>.filled(7, 0);
    final postNegativePerDay = List<int>.filled(7, 0);
    final Map<String, Map<String, int>> colorByEmotion = {};
    int totalSessions = 0;

    void incColour(String emotion, String? hex) {
      if (hex == null || hex.isEmpty) return;
      final norm = hex.toUpperCase();
      colorByEmotion
          .putIfAbsent(emotion, () => <String, int>{})
          .update(norm, (v) => v + 1, ifAbsent: () => 1);
    }

    for (final s in weekSessions) {
      final tsRaw = s['session_date'] as String? ?? '';
      final ts = DateTime.tryParse(tsRaw)?.toLocal();
      final dow = ts == null ? -1 : ts.weekday % 7; // Sun=0..Sat=6

      final preName = (s['pre_emotion_name'] as String?)?.trim();
      final postName = (s['post_emotion_name'] as String?)?.trim();

      // Only process COMPLETE sessions (both pre AND post recorded)
      if (preName == null ||
          preName.isEmpty ||
          postName == null ||
          postName.isEmpty) continue;

      // Pre emotion
      preFreq[preName] = (preFreq[preName] ?? 0) + 1;
      if (dow >= 0 && dow < 7) {
        prePerDay[dow]++;
        if (positiveSet.contains(preName)) {
          prePositivePerDay[dow]++;
        } else if (negativeSet.contains(preName)) {
          preNegativePerDay[dow]++;
        }
      }
      incColour(preName, (s['pre_emotion_colour'] as String?)?.trim());

      // Post emotion
      postFreq[postName] = (postFreq[postName] ?? 0) + 1;
      if (dow >= 0 && dow < 7) {
        postPerDay[dow]++;
        if (positiveSet.contains(postName)) {
          postPositivePerDay[dow]++;
        } else if (negativeSet.contains(postName)) {
          postNegativePerDay[dow]++;
        }
      }
      incColour(postName, (s['post_emotion_colour'] as String?)?.trim());
      totalSessions++;
    }

    // ── Zone & Regulation Tracking ────────────────────────────────
    // Compute regulation deltas (pre - post zone) and per-day averages
    // from the same weekSessions list. Skip sessions with missing zone data.
    final regulationDeltas = <int>[];
    int mismatchCount = 0;
    final preZoneSumPerDay = List<double>.filled(7, 0);
    final preZoneCountPerDay = List<int>.filled(7, 0);
    final postZoneSumPerDay = List<double>.filled(7, 0);
    final postZoneCountPerDay = List<int>.filled(7, 0);

    for (final s in weekSessions) {
      // Skip incomplete sessions
      final preCheck = (s['pre_emotion_name'] as String?)?.trim();
      final postCheck = (s['post_emotion_name'] as String?)?.trim();
      if (preCheck == null ||
          preCheck.isEmpty ||
          postCheck == null ||
          postCheck.isEmpty) continue;

      final tsRaw = s['session_date'] as String? ?? '';
      final ts = DateTime.tryParse(tsRaw)?.toLocal();
      final dow = ts == null ? -1 : ts.weekday % 7;

      final preZone = (s['pre_zone_value'] as num?)?.toInt();
      final postZone = (s['post_zone_value'] as num?)?.toInt();
      final delta = (s['regulation_delta'] as num?)?.toInt();
      final mismatch = s['sensory_mismatch'] as bool? ?? false;

      if (preZone != null && dow >= 0 && dow < 7) {
        preZoneSumPerDay[dow] += preZone;
        preZoneCountPerDay[dow]++;
      }
      if (postZone != null && dow >= 0 && dow < 7) {
        postZoneSumPerDay[dow] += postZone;
        postZoneCountPerDay[dow]++;
      }
      if (delta != null) regulationDeltas.add(delta);
      if (mismatch) mismatchCount++;
    }

    final preZonePerDay = List<double>.generate(7, (i) {
      return preZoneCountPerDay[i] == 0
          ? double.nan
          : preZoneSumPerDay[i] / preZoneCountPerDay[i];
    });
    final postZonePerDay = List<double>.generate(7, (i) {
      return postZoneCountPerDay[i] == 0
          ? double.nan
          : postZoneSumPerDay[i] / postZoneCountPerDay[i];
    });

    // ── Goals snapshot ────────────────────────────────────────────
    // _activeGoals is already loaded with profile-scoped real progress.
    final goalSnapshots = <_GoalSnapshot>[];
    for (final g in _activeGoals) {
      final colourName = g['color'] as String? ?? 'purple';
      final argb = _goalColourArgb(colourName);
      goalSnapshots.add(_GoalSnapshot(
        label: g['label'] as String? ?? '',
        current: (g['current'] as num?)?.toInt() ?? 0,
        target: (g['target'] as num?)?.toInt() ?? 0,
        emoji: g['emoji'] as String? ?? '🎯',
        colorValue: argb,
      ));
    }

    return _WeekMetrics(
      emotionFreq: freq,
      positivePerDay: positivePerDay,
      negativePerDay: negativePerDay,
      sessionsPerDay: sessionsPerDay,
      gameMinutes: gameMinutes,
      gameSeconds: Map.from(gameSecs),
      preEmotionFreq: preFreq,
      postEmotionFreq: postFreq,
      prePerDay: prePerDay,
      postPerDay: postPerDay,
      prePositivePerDay: prePositivePerDay,
      preNegativePerDay: preNegativePerDay,
      postPositivePerDay: postPositivePerDay,
      postNegativePerDay: postNegativePerDay,
      colorByEmotion: colorByEmotion,
      goals: goalSnapshots,
      starsEarned: starsEarned,
      totalSessions: totalSessions,
      regulationDeltas: regulationDeltas,
      mismatchCount: mismatchCount,
      preZonePerDay: preZonePerDay,
      postZonePerDay: postZonePerDay,
    );
  }

  /// Map the symbolic colour name produced by `_activeGoalsWithProgress`
  /// to an ARGB int that `_GoalSnapshot.colorValue` accepts.
  int _goalColourArgb(String colour) {
    switch (colour) {
      case 'orange':
        return 0xFFF59E0B;
      case 'blue':
        return 0xFF3B82F6;
      case 'teal':
        return 0xFF14B8A6;
      case 'purple':
        return 0xFF8B5CF6;
      default:
        return 0xFF8B5CF6;
    }
  }

  /// Parse a `#RRGGBB` (or `#AARRGGBB`) hex string into a [Color].
  /// Falls back to grey for empty/garbage input.
  Color _hexToColor(String hex) {
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    if (v == null) return Colors.grey.shade400;
    return Color(v);
  }

  /// Friendly short label for a colour hex used inside flashcards.
  /// We don't need a full named-colour resolver — the closest of the
  /// 12 EmoLor palette swatches is good enough for caregiver-facing
  /// copy.
  String _humanHex(String hex) {
    const named = <String, String>{
      '#EF4444': 'Red',
      '#F97316': 'Orange',
      '#FFE66D': 'Yellow',
      '#22C55E': 'Green',
      '#7ED957': 'Green',
      '#4ECDC4': 'Teal',
      '#60A5FA': 'Blue',
      '#74B9FF': 'Light Blue',
      '#8B5CF6': 'Purple',
      '#A29BFE': 'Lavender',
      '#EC4899': 'Pink',
      '#FF7EB3': 'Rose',
      '#FF9F43': 'Amber',
      '#FFB088': 'Peach',
      '#9CA3AF': 'Grey',
    };
    final norm = hex.toUpperCase();
    return named[norm] ?? hex;
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
      positivePerDay:
          List.generate(7, (i) => i <= dowSun ? m.positivePerDay[i] : 0),
      negativePerDay:
          List.generate(7, (i) => i <= dowSun ? m.negativePerDay[i] : 0),
      sessionsPerDay:
          List.generate(7, (i) => i <= dowMon ? m.sessionsPerDay[i] : 0),
      gameMinutes: m.gameMinutes,
      gameSeconds: m.gameSeconds,
      // Pre/post frequency maps only contain days already logged — safe as-is.
      preEmotionFreq: m.preEmotionFreq,
      postEmotionFreq: m.postEmotionFreq,
      prePerDay: List.generate(7, (i) => i <= dowSun ? m.prePerDay[i] : 0),
      postPerDay: List.generate(7, (i) => i <= dowSun ? m.postPerDay[i] : 0),
      prePositivePerDay:
          List.generate(7, (i) => i <= dowSun ? m.prePositivePerDay[i] : 0),
      preNegativePerDay:
          List.generate(7, (i) => i <= dowSun ? m.preNegativePerDay[i] : 0),
      postPositivePerDay:
          List.generate(7, (i) => i <= dowSun ? m.postPositivePerDay[i] : 0),
      postNegativePerDay:
          List.generate(7, (i) => i <= dowSun ? m.postNegativePerDay[i] : 0),
      colorByEmotion: m.colorByEmotion,
      goals: m.goals,
      starsEarned: m.starsEarned,
      totalSessions: m.totalSessions,
      regulationDeltas: m.regulationDeltas,
      mismatchCount: m.mismatchCount,
      // Trim zone arrays the same way — keep days up to today, NaN beyond.
      preZonePerDay: List.generate(
          7, (i) => i <= dowSun ? m.preZonePerDay[i] : double.nan),
      postZonePerDay: List.generate(
          7, (i) => i <= dowSun ? m.postZonePerDay[i] : double.nan),
    );
  }

  /// Build the prompt sent to Claude.
  ///
  /// Covers exactly the data shown on the dashboard:
  ///   • 6 Home tab flashcards (Total Sessions, Week's Emotion Trend,
  ///     Top Pre/Post Emotion, Top Mood Colour, Top Activity)
  ///   • 3 Progress tab charts (Emotion Trend, Emotion Distribution,
  ///     Emotion–Colour Association)
  ///
  /// Goals, rewards and stars are intentionally excluded.
  /// Empty days / zero-count entries are filtered so the model cannot
  /// hallucinate data that was never logged.
  String _buildAiPrompt(_WeekMetrics m, int offset) {
    final start = _weekStartDate(offset);
    final end = start.add(const Duration(days: 6));
    String two(int n) => n.toString().padLeft(2, '0');
    String fmt(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';
    const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    // ── Flashcard 1: Total Sessions ──────────────────────────────────
    final totalSessions = m.totalSessions;

    // ── Flashcard 2: Week's Emotion Trend ────────────────────────────
    // Logic: each complete session has a pre+post combination.
    // pre pos + post pos = positive session
    // pre pos + post neg = negative session
    // pre neg + post pos = positive session
    // pre neg + post neg = negative session
    // More positive sessions = Positive Trend, else Negative Trend.
    int positiveSessionCount = 0;
    int negativeSessionCount = 0;

    // Use per-day data to derive session combinations
    for (int i = 0; i < 7; i++) {
      final prePos = m.prePositivePerDay[i];
      final preNeg = m.preNegativePerDay[i];
      final postPos = m.postPositivePerDay[i];
      final postNeg = m.postNegativePerDay[i];

      // Determine dominant pre and post for this day
      final preIsPosDay = prePos >= preNeg;
      final postIsPosDay = postPos >= postNeg;

      final daySessionCount =
          [prePos + preNeg, postPos + postNeg].reduce((a, b) => a < b ? a : b);

      if (daySessionCount > 0) {
        if (postIsPosDay) {
          positiveSessionCount += daySessionCount;
        } else {
          negativeSessionCount += daySessionCount;
        }
      }
    }

    final totalSessionCombinations =
        positiveSessionCount + negativeSessionCount;
    String trendLabel;
    if (totalSessionCombinations == 0) {
      trendLabel = 'Not enough data';
    } else {
      trendLabel = positiveSessionCount >= negativeSessionCount
          ? 'Positive Trend'
          : 'Negative Trend';
    }

    // ── Flashcard 3: Top Pre-Session Emotion ─────────────────────────
    MapEntry<String, int>? preTop;
    for (final e in m.preEmotionFreq.entries) {
      if (e.value > 0 && (preTop == null || e.value > preTop!.value)) {
        preTop = e;
      }
    }
    final preTopStr =
        preTop != null ? '${preTop!.key} (${preTop!.value}×)' : '—';

    // ── Flashcard 4: Top Post-Session Emotion ────────────────────────
    MapEntry<String, int>? postTop;
    for (final e in m.postEmotionFreq.entries) {
      if (e.value > 0 && (postTop == null || e.value > postTop!.value)) {
        postTop = e;
      }
    }
    final postTopStr =
        postTop != null ? '${postTop!.key} (${postTop!.value}×)' : '—';

    // ── Flashcard 5: Top Mood Colour ─────────────────────────────────
    String topColourEmotion = '—';
    String topColourHex = '';
    int topColourCount = 0;
    m.colorByEmotion.forEach((emotion, byHex) {
      byHex.forEach((hex, count) {
        if (count > topColourCount) {
          topColourCount = count;
          topColourEmotion = emotion;
          topColourHex = hex;
        }
      });
    });
    final topColourName = topColourCount > 0
        ? (SensoryPalette.fromHex(topColourHex)?.label ??
            _humanHex(topColourHex))
        : '';
    final topColourStr = topColourCount > 0
        ? '$topColourEmotion — $topColourName ($topColourCount×)'
        : '—';

    // ── Flashcard 6: Top Activity ─────────────────────────────────────
    String topActivityName = '—';
    int topActivitySecs = 0;
    m.gameSeconds.forEach((name, secs) {
      if (secs > topActivitySecs) {
        topActivitySecs = secs;
        topActivityName = name;
      }
    });
    final int topActivityMins = (topActivitySecs / 60).round();
    final topActivityStr =
        topActivitySecs > 0 ? '$topActivityName ($topActivityMins min)' : '—';

    // ── Regulation Trend per day (for Progress chart context) ─────────
    final zoneTrendLines = <String>[];
    for (int i = 0; i < 7; i++) {
      final pre = m.preZonePerDay[i];
      final post = m.postZonePerDay[i];
      if (pre.isNaN && post.isNaN) continue;
      final preStr = pre.isNaN ? 'no data' : pre.toStringAsFixed(1);
      final postStr = post.isNaN ? 'no data' : post.toStringAsFixed(1);
      zoneTrendLines
          .add('  - ${dayNames[i]}: Pre-zone $preStr → Post-zone $postStr');
    }

    // ── Chart 1: Emotion Trend (pre/post × positive/negative per day) ──
    final trendLines = <String>[];
    for (int i = 0; i < 7; i++) {
      final preP = m.prePositivePerDay[i];
      final preN = m.preNegativePerDay[i];
      final postP = m.postPositivePerDay[i];
      final postN = m.postNegativePerDay[i];
      if (preP + preN + postP + postN == 0) continue;
      trendLines
          .add('  - ${dayNames[i]}: Pre(+$preP/-$preN)  Post(+$postP/-$postN)');
    }

    // ── Chart 2: Emotion Distribution ────────────────────────────────
    final preFreqStr = m.preEmotionFreq.entries
        .where((e) => e.value > 0)
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');
    final postFreqStr = m.postEmotionFreq.entries
        .where((e) => e.value > 0)
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');

    // ── Chart 3: Emotion–Colour Association ──────────────────────────
    final colourLines = <String>[];
    m.colorByEmotion.forEach((emotion, byHex) {
      final pairs = byHex.entries.where((e) => e.value > 0).map((e) {
        final name = SensoryPalette.fromHex(e.key)?.label ?? _humanHex(e.key);
        return '$name(${e.value}×)';
      }).join(', ');
      if (pairs.isNotEmpty) colourLines.add('  - $emotion → $pairs');
    });

    final todayName = dayNames[DateTime.now().weekday % 7];
    final cutoffNote = offset == 0
        ? 'IMPORTANT: Today is ${fmt(DateTime.now())} ($todayName). '
            'Only data from Monday up to and including TODAY is available. '
            'Days after today have NO data yet — do NOT reference or speculate about them. '
            'Only summarise based on the data rows actually listed below.'
        : 'This is the complete data for ${fmt(start)} – ${fmt(end)}.';

    return '''
You are summarising one child's EMOLOR app usage for their parent or caregiver.

Week: ${fmt(start)} – ${fmt(end)}
$cutoffNote

=== HOME TAB FLASHCARDS ===
Total Sessions this week: $totalSessions
Week's Emotion Trend: $trendLabel
Top Pre-Session Emotion: $preTopStr
Top Post-Session Emotion: $postTopStr
Top Mood Colour: $topColourStr
Top Activity: $topActivityStr

=== PROGRESS CHARTS ===

CHART 1 — Emotion Trend (Pre vs Post, Positive vs Negative, per day):
${trendLines.isEmpty ? '  (no data)' : trendLines.join('\n')}

CHART 2 — Emotion Distribution:
  Pre-session:  ${preFreqStr.isEmpty ? '(none)' : preFreqStr}
  Post-session: ${postFreqStr.isEmpty ? '(none)' : postFreqStr}

CHART 3 — Emotion–Colour Association:
${colourLines.isEmpty ? '  (no colour data)' : colourLines.join('\n')}

CHART 4 — Regulation Trend (sensory zone -2 to +3 per day):
Zone scale: +3=Overload, +2=Elevated, 0=Balanced, -1=Low Energy, -2=Withdrawal
${zoneTrendLines.isEmpty ? '  (no zone data yet)' : zoneTrendLines.join('\n')}

=== INSTRUCTIONS ===
Generate a short caregiver-friendly weekly insight summary for EMOLOR.

STRICT RULES:
- Keep it between 120-180 words total.
- Use simple, warm, non-technical language.
- Do NOT list every chart value or mention "Chart 1", "Chart 2", "Chart 3".
- Summarise only the most meaningful patterns from the data above.
- Do NOT invent data. Do NOT mention future days beyond ${fmt(DateTime.now())}.
- If data is limited, say insights are still developing.
- Do not use markdown, bullet points, or tables.

Focus on:
1. Overall emotion trend (positive or negative)
2. Regulation trend — whether the child's sensory zone improved (lower score) or worsened (higher score) from pre to post session each day. Use plain language like "your child tended to feel more settled/calm after sessions" or "sessions left them more activated/overwhelmed". If zone data is available, always mention this.
3. Most engaged activity
4. Notable colour-emotion pattern
5. One practical caregiver recommendation

Output using EXACTLY this format (no extra headings, no bullets):

EMOLOR Weekly Insight Summary
${fmt(start)} - ${fmt(end)}
[1 short paragraph about overall emotion trend and sessions]
[1 short paragraph about regulation trend — how the child's sensory zone shifted before vs after sessions]
[1 short paragraph about top activity and colour-emotion pattern]
Caregiver Note:
[1 short practical recommendation sentence]
''';
  }

  /// Triggered by the "Generate Insight Summary" / "Regenerate" button.
  ///
  /// • Builds metrics for the selected week (trimmed to today for
  ///   "This Week" so future days are never sent to the model).
  /// • Short-circuits with a fixed message when the week has no data.
  /// • Stores the result in [_aiInsightByWeek] keyed by week offset so
  ///   switching weeks and switching back does not lose the summary.
  Future<void> _generateAiInsight() async {
    if (_aiLoading) return;
    final weekKey = _selectedWeekOffset;
    setState(() {
      _aiLoading = true;
      _aiError = null;
      // Clear only the current week's cached summary so a "Regenerate"
      // click actually refetches.
      _aiInsightByWeek.remove(weekKey);
    });

    try {
      // For "This Week" we only feed Sun → today.  Past weeks (sample
      // data) get the full snapshot.
      var metrics = _metricsForWeek(weekKey);
      if (weekKey == 0) {
        metrics = _trimMetricsToToday(metrics);
      }

      // Empty-data short-circuit — never burn an API call on a blank week.
      final hasAny = metrics.preEmotionFreq.values.any((v) => v > 0) ||
          metrics.postEmotionFreq.values.any((v) => v > 0) ||
          metrics.gameSeconds.values.any((v) => v > 0) ||
          metrics.sessionsPerDay.any((v) => v > 0);
      if (!hasAny) {
        if (!mounted) return;
        setState(() {
          _aiInsightByWeek[weekKey] =
              'No data available yet. Start using EMOLOR this week to generate an insight summary.';
          _aiLoading = false;
        });
        return;
      }

      final prompt = _buildAiPrompt(metrics, weekKey);
      final summary = await AiInsightService.generateInsight(prompt);
      if (!mounted) return;
      await _saveAiInsight(weekKey, summary);
      if (!mounted) return;
      setState(() {
        _aiInsightByWeek[weekKey] = summary;
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
              const Icon(Icons.psychology, color: Color(0xFFC026D3), size: 26),
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
                    _aiInsightByWeek[_selectedWeekOffset] == null
                        ? Icons.auto_awesome
                        : Icons.refresh_rounded,
                    color: Colors.white,
                    size: 18),
                label: Text(
                  _aiInsightByWeek[_selectedWeekOffset] == null
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  style:
                      _textStyle(fontSize: 14, color: const Color(0xFF86198F))),
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
                      style: _textStyle(fontSize: 13, color: Colors.red[700]!)),
                ),
              ]),
            )
          else if (_aiInsightByWeek[_selectedWeekOffset] != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _aiInsightByWeek[_selectedWeekOffset]!,
                  style: _textStyle(
                          fontSize: 16,
                          color: const Color(0xFF4A044E),
                          fontWeight: FontWeight.w500)
                      .copyWith(height: 1.5),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                          text: _aiInsightByWeek[_selectedWeekOffset]!));
                    },
                    icon: const Icon(Icons.copy_rounded,
                        color: Color(0xFFC026D3), size: 18),
                    label: Text('Copy Summary',
                        style: _textStyle(
                            fontSize: 14,
                            color: const Color(0xFFC026D3),
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
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

  // ── PDF report generation (Progress tab) ────────────────────────
  //
  // Builds a [WeeklyPdfReportPayload] for the currently-selected week
  // and hands it off to [WeeklyPdfReportService]. Real data only for
  // "This Week"; static fake snapshots for past weeks. Real and fake
  // data never mix, and fake data is NEVER persisted to Supabase.
  Future<void> _generatePdfReport() async {
    if (_pdfGenerating) return;
    setState(() => _pdfGenerating = true);

    try {
      // Safety net: if age is missing, brute-force resolve it before
      // building the payload so the report never shows "-".
      if (_childAge == null) {
        try {
          String? dob;

          // 1. Try the resolved child user_id first.
          if (_childUserId != null) {
            final p = await Supabase.instance.client
                .from('profiles')
                .select('date_of_birth')
                .eq('user_id', _childUserId!)
                .maybeSingle();
            final d = p?['date_of_birth'] as String?;
            if (d != null && d.isNotEmpty) dob = d;
          }

          // 2. If still nothing, try the currently signed-in user's profile
          //    (works when a child is signed in directly).
          if (dob == null) {
            final uid = Supabase.instance.client.auth.currentUser?.id;
            if (uid != null) {
              final p = await Supabase.instance.client
                  .from('profiles')
                  .select('date_of_birth, role')
                  .eq('user_id', uid)
                  .maybeSingle();
              final d = p?['date_of_birth'] as String?;
              if (d != null && d.isNotEmpty) dob = d;
            }
          }

          // 3. Last resort: find any linked child of the current caregiver
          //    with a valid date_of_birth — prefers one matching _childName.
          if (dob == null) {
            final uid = Supabase.instance.client.auth.currentUser?.id;
            if (uid != null) {
              try {
                final rows = await Supabase.instance.client
                    .from('family_links')
                    .select(
                        'profiles!family_links_child_id_fkey(full_name, date_of_birth)')
                    .eq('caregiver_id', uid);
                if (rows is List) {
                  // Prefer the linked child whose name matches _childName.
                  for (final r in rows) {
                    final p = r['profiles'] as Map<String, dynamic>?;
                    if (p == null) continue;
                    final name = p['full_name'] as String?;
                    final d = p['date_of_birth'] as String?;
                    if (name == _childName && d != null && d.isNotEmpty) {
                      dob = d;
                      break;
                    }
                  }
                  // Otherwise take the first child with a DOB.
                  if (dob == null) {
                    for (final r in rows) {
                      final p = r['profiles'] as Map<String, dynamic>?;
                      final d = p?['date_of_birth'] as String?;
                      if (d != null && d.isNotEmpty) {
                        dob = d;
                        break;
                      }
                    }
                  }
                }
              } catch (_) {}
            }
          }

          if (dob != null) _computeAge(dob);
          debugPrint('PDF age resolution: dob=$dob, _childAge=$_childAge');
        } catch (e) {
          debugPrint('PDF age resolution error: $e');
        }
      }

      // Single source of truth — same metrics object the on-screen
      // charts consume for the selected week. Real data for offset 0,
      // static fake snapshot for past weeks. Real and fake never mix,
      // and fake data is NEVER persisted to Supabase.
      final metrics = _metricsForWeek(_selectedWeekOffset);
      final start = _weekStartDate(_selectedWeekOffset);
      final end = start.add(const Duration(days: 6));
      String two(int n) => n.toString().padLeft(2, '0');
      String fmt(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';
      // Plain ASCII hyphen — em-dashes were rendering as box / X tofu
      // in the previous Helvetica-only PDF.
      final weekRange = '${fmt(start)} - ${fmt(end)}';
      final shortLabel = _selectedWeekOffset == 0
          ? 'This Week'
          : (_selectedWeekOffset == -1 ? 'Last Week' : '2 Weeks Ago');

      debugPrint('PDF childName: $_childName, childAge: $_childAge');
      // ── Flashcard computations ──────────────────────────────────
      // Flashcard 1: Total sessions
      final pdfTotalSessions = metrics.totalSessions;

      // Flashcard 2: Emotion trend via session combinations
      int pdfPosCount = 0, pdfNegCount = 0;
      for (int i = 0; i < 7; i++) {
        final prePos = metrics.prePositivePerDay[i];
        final preNeg = metrics.preNegativePerDay[i];
        final postPos = metrics.postPositivePerDay[i];
        final postNeg = metrics.postNegativePerDay[i];
        final postIsPosDay = postPos >= postNeg;
        final dayCount = [prePos + preNeg, postPos + postNeg]
            .reduce((a, b) => a < b ? a : b);
        if (dayCount > 0) {
          if (postIsPosDay)
            pdfPosCount += dayCount;
          else
            pdfNegCount += dayCount;
        }
      }
      final pdfTotalCombinations = pdfPosCount + pdfNegCount;
      final pdfTrendLabel = pdfTotalCombinations == 0
          ? 'Not Enough Data'
          : pdfPosCount >= pdfNegCount
              ? 'Positive Trend'
              : 'Negative Trend';

      // Flashcard 3: Top pre emotion
      MapEntry<String, int>? pdfPreTop;
      metrics.preEmotionFreq.forEach((k, v) {
        if (v > 0 && (pdfPreTop == null || v > pdfPreTop!.value))
          pdfPreTop = MapEntry(k, v);
      });

      // Flashcard 4: Top post emotion
      MapEntry<String, int>? pdfPostTop;
      metrics.postEmotionFreq.forEach((k, v) {
        if (v > 0 && (pdfPostTop == null || v > pdfPostTop!.value))
          pdfPostTop = MapEntry(k, v);
      });

      // Flashcard 5: Top mood colour
      String pdfTopColourEmotion = '—';
      String pdfTopColourHex = '';
      String pdfTopColourName = '—';
      int pdfTopColourCount = 0;
      metrics.colorByEmotion.forEach((emotion, byHex) {
        byHex.forEach((hex, count) {
          if (count > pdfTopColourCount) {
            pdfTopColourCount = count;
            pdfTopColourEmotion = emotion;
            pdfTopColourHex = hex;
            pdfTopColourName = SensoryPalette.fromHex(hex)?.label ?? hex;
          }
        });
      });

      // Flashcard 6: Top activity — compare by raw seconds to avoid
      // rounding short sessions to 0 min.
      String pdfTopActivity = '—';
      int pdfTopActivitySecs = 0;
      metrics.gameSeconds.forEach((name, secs) {
        if (secs > pdfTopActivitySecs) {
          pdfTopActivitySecs = secs;
          pdfTopActivity = name;
        }
      });
      final int pdfTopActivityMins = (pdfTopActivitySecs / 60).round();

      // ── Chart 3: Dominant colour per emotion ───────────────────
      const pdfEmotionOrder = [
        'Happy',
        'Sad',
        'Angry',
        'Scared',
        'Excited',
        'Calm',
        'Tired',
        'Loved',
      ];
      final List<PdfColorAssocBar> pdfColorAssoc = [];
      for (final emotion in pdfEmotionOrder) {
        final byHex = metrics.colorByEmotion[emotion];
        if (byHex == null || byHex.isEmpty) continue;
        final dominant =
            byHex.entries.reduce((a, b) => a.value >= b.value ? a : b);
        if (dominant.value > 0) {
          pdfColorAssoc.add(PdfColorAssocBar(
            emotion: emotion,
            hex: dominant.key,
            count: dominant.value,
          ));
        }
      }

      // ── Emotion freq: positive vs negative (combined pre+post) ──
      final Map<String, int> pdfEmotionFreq = {}; // positive emotions
      final Map<String, int> pdfPostEmotionFreq = {}; // negative emotions
      void addToSplit(Map<String, int> source) {
        source.forEach((k, v) {
          if (_kPositiveEmotions.contains(k)) {
            pdfEmotionFreq[k] = (pdfEmotionFreq[k] ?? 0) + v;
          } else if (_kNegativeEmotions.contains(k)) {
            pdfPostEmotionFreq[k] = (pdfPostEmotionFreq[k] ?? 0) + v;
          }
        });
      }

      addToSplit(metrics.preEmotionFreq);
      addToSplit(metrics.postEmotionFreq);

      debugPrint('PDF childName: $_childName, childAge: $_childAge');
      final payload = WeeklyPdfReportPayload(
        childName: _childName,
        childAge: _childAge,
        weekRangeLabel: weekRange,
        weekShortLabel: shortLabel,
        totalSessions: pdfTotalSessions,
        emotionTrendLabel: pdfTrendLabel,
        positiveSessionCount: pdfPosCount,
        negativeSessionCount: pdfNegCount,
        topPreEmotion: pdfPreTop?.key ?? '—',
        topPreCount: pdfPreTop?.value ?? 0,
        topPostEmotion: pdfPostTop?.key ?? '—',
        topPostCount: pdfPostTop?.value ?? 0,
        topMoodColourEmotion: pdfTopColourEmotion,
        topMoodColourName: pdfTopColourName,
        topMoodColourCount: pdfTopColourCount,
        topActivityName: pdfTopActivity,
        topActivityMinutes: pdfTopActivityMins,
        prePositivePerDay: metrics.prePositivePerDay,
        preNegativePerDay: metrics.preNegativePerDay,
        postPositivePerDay: metrics.postPositivePerDay,
        postNegativePerDay: metrics.postNegativePerDay,
        emotionFreq: pdfEmotionFreq,
        postEmotionFreq: pdfPostEmotionFreq,
        colorAssoc: pdfColorAssoc,
        preZonePerDay: metrics.preZonePerDay,
        postZonePerDay: metrics.postZonePerDay,
        aiSummary: _aiInsightByWeek[_selectedWeekOffset],
      );

      await WeeklyPdfReportService.generate(payload);
    } catch (e, stack) {
      debugPrint('PDF report error: $e');
      debugPrint('PDF report stack: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _pdfGenerating = false);
    }
  }

  // ── Calendar-style week selector pill ───────────────────────────
  //
  // Tapping the pill opens a dialog with three selectable week rows
  // (This Week / Last Week / 2 Weeks Ago).  The pill itself shows:
  //   • a calendar icon
  //   • the short label ("This Week" / …) in small text above
  //   • the full date range ("Mon 27 Apr – Sun 3 May") below
  //   • a down-arrow to hint it is tappable
  Widget _buildWeekSelector() {
    return GestureDetector(
      onTap: _showWeekPickerDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE9D5FF), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  color: Color(0xFF7C3AED), size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _weekOffsetLabel(_selectedWeekOffset),
                  style: _textStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9333EA)),
                ),
                Text(
                  _weekDateRange(_selectedWeekOffset),
                  style: _textStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6B21A8)),
                ),
                if (_selectedWeekOffset == 0)
                  Text(
                    'Current Week',
                    style: _textStyle(
                        fontSize: 10,
                        color: const Color(0xFF9333EA).withValues(alpha: 0.7)),
                  ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF7C3AED), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    // Single source of truth for the selected week — real data for "This
    // Week", static fake snapshot for past weeks. Every flashcard reads
    // from this object and ONLY this object, so labels and numbers can
    // never drift apart.
    final metrics = _metricsForWeek(_selectedWeekOffset);

    // Helper — pick the highest-count emotion from a frequency map.
    MapEntry<String, int>? topEntry(Map<String, int> m) {
      if (m.isEmpty) return null;
      return m.entries.reduce((a, b) => b.value > a.value ? b : a);
    }

    // ── Card 1 — Total Sessions (fully-completed pre+post pairs) ─
    final int totalSessions = metrics.totalSessions;
    final String sessionsValue = '$totalSessions';
    final String sessionsSub = totalSessions == 0
        ? 'No sessions yet'
        : (totalSessions == 1 ? 'session this week' : 'sessions this week');

    // ── Card 2 — Most Common Pre-Session Emotion ─────────────────
    final preTop = topEntry(metrics.preEmotionFreq);
    final preName = preTop?.key ?? '—';
    final preEmoji = preTop != null ? (_eEmojis[preName] ?? '🙂') : '🌤️';
    final preSub = preTop != null
        ? '${preTop.value}× before sessions'
        : 'No pre-session data';

    // ── Card 3 — Most Common Post-Session Emotion ────────────────
    final postTop = topEntry(metrics.postEmotionFreq);
    final postName = postTop?.key ?? '—';
    final postEmoji = postTop != null ? (_eEmojis[postName] ?? '🙂') : '🌤️';
    final postSub = postTop != null
        ? '${postTop.value}× after sessions'
        : 'No post-session data';

    // ── Card 4 — Top Mood Colour ─────────────────────────────────
    // Pick the emotion-colour pair the child reached for most this week.
    String topColourEmotion = '—';
    String topColourHex = '';
    int topColourCount = 0;
    metrics.colorByEmotion.forEach((emotion, byHex) {
      byHex.forEach((hex, count) {
        if (count > topColourCount) {
          topColourCount = count;
          topColourEmotion = emotion;
          topColourHex = hex;
        }
      });
    });
    final Color topColourSwatch = topColourCount > 0
        ? _hexToColor(topColourHex)
        : (postTop != null
            ? EmotionColourMapping.colorFor(postName)
            : Colors.grey.shade400);
    // Color name is the main value, emotion shown below
    final String topColourValue = topColourCount > 0
        ? (SensoryPalette.fromHex(topColourHex)?.label ??
            _humanHex(topColourHex))
        : '—';
    final String topColourSub = topColourCount > 0
        ? '$topColourEmotion · $topColourCount×'
        : 'No colour pairs yet';

    // ── Card 5 — Week's Emotion Trend ────────────────────────────
    // Aggregates positive vs negative emotion choices across BOTH
    // pre-session and post-session selections for the selected week.
    // Drives the same calculation the Progress-tab Emotion Trend chart
    // visualises, so the home flashcard and the chart can never disagree.
    int countByPolarity(Map<String, int> freq, Set<String> set) {
      var n = 0;
      freq.forEach((emotion, count) {
        if (set.contains(emotion)) n += count;
      });
      return n;
    }

    final int posCount =
        countByPolarity(metrics.preEmotionFreq, _kPositiveEmotions) +
            countByPolarity(metrics.postEmotionFreq, _kPositiveEmotions);
    final int negCount =
        countByPolarity(metrics.preEmotionFreq, _kNegativeEmotions) +
            countByPolarity(metrics.postEmotionFreq, _kNegativeEmotions);
    final int polarityTotal = posCount + negCount;

    // Compute session combinations for trend
    int positiveSessionCount = 0;
    int negativeSessionCount = 0;
    for (int i = 0; i < 7; i++) {
      final prePos = metrics.prePositivePerDay[i];
      final preNeg = metrics.preNegativePerDay[i];
      final postPos = metrics.postPositivePerDay[i];
      final postNeg = metrics.postNegativePerDay[i];
      final postIsPosDay = postPos >= postNeg;
      final daySessionCount =
          [prePos + preNeg, postPos + postNeg].reduce((a, b) => a < b ? a : b);
      if (daySessionCount > 0) {
        if (postIsPosDay) {
          positiveSessionCount += daySessionCount;
        } else {
          negativeSessionCount += daySessionCount;
        }
      }
    }
    final int totalSessionCombinations =
        positiveSessionCount + negativeSessionCount;

    String trendEmoji;
    String trendValue;
    Color trendColour;
    String trendSub;
    if (totalSessionCombinations == 0) {
      trendEmoji = '🌤️';
      trendValue = '—';
      trendColour = const Color(0xFF9CA3AF);
      trendSub = 'No sessions this week';
    } else {
      if (positiveSessionCount >= negativeSessionCount) {
        trendEmoji = '🌈';
        trendValue = 'Positive Trend';
        trendColour = const Color(0xFF10B981);
      } else {
        trendEmoji = '🌧️';
        trendValue = 'Negative Trend';
        trendColour = const Color(0xFFEF4444);
      }
      trendSub =
          '$positiveSessionCount positive · $negativeSessionCount negative sessions';
    }

    // ── Card 6 — Top Activity ────────────────────────────────────
    // Activity (game / Draw) with the largest total time-spent in the
    // selected week. Uses raw seconds (gameSeconds) so short sessions
    // (< 30 s) are never rounded to 0 and silently dropped.
    String topActivityName = '—';
    int topActivitySecs = 0;
    metrics.gameSeconds.forEach((name, secs) {
      if (secs > topActivitySecs) {
        topActivitySecs = secs;
        topActivityName = name;
      }
    });

    final int topActivityMinutes = (topActivitySecs / 60).round();
    final String topActivityValue =
        topActivitySecs > 0 ? _brandedGameName(topActivityName) : '—';
    final String topActivitySub = topActivitySecs > 0
        ? topActivitySecs < 60
            ? '< 1 min this week'
            : '$topActivityMinutes min this week'
        : 'No activity yet';

    final card1 = _buildHomeCard('🎯', 'Total Sessions', sessionsValue,
        const Color(0xFF6366F1), sessionsSub);
    final card2 = _buildHomeCard(preEmoji, 'Top Pre-Session Emotion', preName,
        const Color(0xFF60A5FA), preSub);
    final card3 = _buildHomeCard(postEmoji, 'Top Post-Session Emotion',
        postName, const Color(0xFF10B981), postSub);
    final card4 = _buildHomeCard(
        '🎨', 'Top Mood Colour', topColourValue, topColourSwatch, topColourSub);
    final card5 = _buildHomeCard(
        trendEmoji, "Week's Emotion Trend", trendValue, trendColour, trendSub);
    final card6 = _buildHomeCard('🎮', 'Top Activity', topActivityValue,
        const Color(0xFFF59E0B), topActivitySub);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top bar: title + week selector ───────────────────────
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
            ],
          ),
          const SizedBox(height: 16),
          // ── 6 flashcards in 3 rows × 2 columns ───────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Row 1: Total Sessions | Week's Emotion Trend
                Expanded(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        card1,
                        const SizedBox(width: 12),
                        card5,
                      ]),
                ),
                const SizedBox(height: 12),
                // Row 2: Top Pre-Session Emotion | Top Post-Session Emotion
                Expanded(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        card2,
                        const SizedBox(width: 12),
                        card3,
                      ]),
                ),
                const SizedBox(height: 12),
                // Row 3: Top Mood Colour | Top Activity
                Expanded(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        card4,
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
    final String? touchedEmoji =
        touchedName != null ? (_eEmojis[touchedName] ?? '') : null;

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
                      touchCallback:
                          (FlTouchEvent event, PieTouchResponse? response) {
                        final idx =
                            response?.touchedSection?.touchedSectionIndex ?? -1;
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                      );
                    },
                  ),
                ),
                barGroups: barGroups,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                      color: Colors.grey.withValues(alpha: 0.15),
                      strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      getTitlesWidget: (v, _) {
                        if (v == 2.0)
                          return Text('😊 +',
                              style: _textStyle(
                                  fontSize: 11, color: Colors.grey[600]!));
                        if (v == 0.5)
                          return Text('😔 −',
                              style: _textStyle(
                                  fontSize: 11, color: Colors.grey[600]!));
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= completeSessions.length)
                          return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('S${idx + 1}',
                              style: _textStyle(
                                  fontSize: 12, color: Colors.grey[600]!)),
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
    const positiveEmotions = _kPositiveEmotions;
    const negativeEmotions = _kNegativeEmotions;

    // ── Single source of truth for all 4 charts ─────────────────────
    // Real for "This Week", static fake data for "Last Week" / "2 Weeks
    // Ago". Real and fake data are produced by separate code paths
    // inside _metricsForWeek and never combined.
    final metrics = _metricsForWeek(_selectedWeekOffset);

    // Distribution is based on session emotions (pre + post combined)
    // so it stays aligned with all other session-based analytics.
    final Map<String, int> positiveFreqRecent = {};
    final Map<String, int> negativeFreqRecent = {};
    void addToDistribution(Map<String, int> source) {
      source.forEach((em, count) {
        if (positiveEmotions.contains(em)) {
          positiveFreqRecent[em] = (positiveFreqRecent[em] ?? 0) + count;
        } else if (negativeEmotions.contains(em)) {
          negativeFreqRecent[em] = (negativeFreqRecent[em] ?? 0) + count;
        }
      });
    }

    addToDistribution(metrics.preEmotionFreq);
    addToDistribution(metrics.postEmotionFreq);

    // Distribution panel lists.
    final positiveEmotionsData = positiveFreqRecent.entries.toList();
    final negativeEmotionsData = negativeFreqRecent.entries.toList();

    final totalPositive =
        positiveEmotionsData.fold<int>(0, (s, e) => s + e.value);
    final totalNegative =
        negativeEmotionsData.fold<int>(0, (s, e) => s + e.value);

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
        value: value,
        color: color,
        title: '$percentage%',
        radius: _pieRadius,
        titleStyle: _pieLabelStyle,
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
        value: value,
        color: color,
        title: '$percentage%',
        radius: _pieRadius,
        titleStyle: _pieLabelStyle,
      );
    }).toList();

    if (pieSectionsPositive.isEmpty) {
      pieSectionsPositive.add(PieChartSectionData(
          value: 1,
          color: const Color(0xFF10B981),
          title: '0%',
          radius: _pieRadius,
          titleStyle: _pieLabelStyle));
    }
    if (pieSectionsNegative.isEmpty) {
      pieSectionsNegative.add(PieChartSectionData(
          value: 1,
          color: const Color(0xFFEF4444),
          title: '0%',
          radius: _pieRadius,
          titleStyle: _pieLabelStyle));
    }

    // ── Emotion Trend (PRE vs POST session per day, stacked by sentiment) ─
    // Each day shows two bars side-by-side: Pre (left) and Post (right).
    // Each bar is internally stacked — green = positive emotions logged,
    // red = negative — so the chart conveys all three dimensions at once:
    //   · weekday (x-axis)
    //   · pre vs post (the two bars per day)
    //   · positive vs negative trend (the colour stacks)
    final prePos = metrics.prePositivePerDay;
    final preNeg = metrics.preNegativePerDay;
    final postPos = metrics.postPositivePerDay;
    final postNeg = metrics.postNegativePerDay;

    const Color cPrePos = Color(0xFF6366F1); // indigo  — pre, positive
    const Color cPreNeg = Color(0xFFC7D2FE); // light indigo — pre, negative
    const Color cPostPos = Color(0xFF10B981); // green   — post, positive
    const Color cPostNeg = Color(0xFFFCA5A5); // light red — post, negative

    BarChartGroupData buildDayGroup(int day) {
      final preTotal = prePos[day] + preNeg[day];
      final postTotal = postPos[day] + postNeg[day];
      return BarChartGroupData(
        x: day,
        barsSpace: 4,
        barRods: [
          BarChartRodData(
            toY: preTotal.toDouble(),
            width: 11,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            rodStackItems: [
              BarChartRodStackItem(0, preNeg[day].toDouble(), cPreNeg),
              BarChartRodStackItem(
                  preNeg[day].toDouble(), preTotal.toDouble(), cPrePos),
            ],
          ),
          BarChartRodData(
            toY: postTotal.toDouble(),
            width: 11,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            rodStackItems: [
              BarChartRodStackItem(0, postNeg[day].toDouble(), cPostNeg),
              BarChartRodStackItem(
                  postNeg[day].toDouble(), postTotal.toDouble(), cPostPos),
            ],
          ),
        ],
      );
    }

    // Display index → data index (Sun=0,Mon=1..Sat=6 in data)
    const _kDisplayToData = [1, 2, 3, 4, 5, 6, 0]; // Mon..Sun
    final emotionTrendGroups = List.generate(7, (displayIdx) {
      final dataIdx = _kDisplayToData[displayIdx];
      return buildDayGroup(dataIdx).copyWith(x: displayIdx);
    });

    final int maxBarValue = [
      ...List.generate(7, (i) => prePos[i] + preNeg[i]),
      ...List.generate(7, (i) => postPos[i] + postNeg[i]),
    ].fold<int>(0, (a, b) => b > a ? b : a);
    final double maxEmotionY =
        maxBarValue < 1 ? 1.0 : (maxBarValue + 1).toDouble();
    final bool hasPrePostData = maxBarValue > 0;

    // ── Goals Progress chart was removed in 3-chart redesign. The
    // metrics.goals list is still populated by the data layer because
    // the PDF report continues to render a goals section.

    // ── Emotion Color Association data ──────────────────────────────
    // Flatten the emotion → (hex → count) map into a list of bars, one
    // per (emotion, hex) pair, sorted by count desc and trimmed to the
    // top 8 so the chart stays readable.
    // ── Emotion Color Association data ──────────────────────────────
    // One bar per emotion — colored with the dominant (most-used) color
    // the child associated with that emotion this week.
    const _kEmotionOrder = [
      'Happy',
      'Sad',
      'Angry',
      'Scared',
      'Excited',
      'Calm',
      'Tired',
      'Loved',
    ];
    final List<({String emotion, String hex, int count})> assocBars = [];
    for (final emotion in _kEmotionOrder) {
      final byHex = metrics.colorByEmotion[emotion];
      if (byHex == null || byHex.isEmpty) {
        // No data yet — add empty placeholder
        assocBars.add((emotion: emotion, hex: '', count: 0));
      } else {
        // Find dominant color
        final dominant =
            byHex.entries.reduce((a, b) => a.value >= b.value ? a : b);
        assocBars
            .add((emotion: emotion, hex: dominant.key, count: dominant.value));
      }
    }
    final topAssoc = assocBars;
    final double assocMaxY = assocBars.any((b) => b.count > 0)
        ? (assocBars.map((b) => b.count).reduce((a, b) => a > b ? a : b) + 1)
            .toDouble()
        : 1.0;
    final bool hasAssocData = assocBars.any((b) => b.count > 0);

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
              action: ElevatedButton.icon(
                icon: _pdfGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf,
                        color: Colors.white, size: 22),
                label: Text(
                    _pdfGenerating ? 'Generating…' : 'Generate PDF Report',
                    style: _textStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B21A8),
                  disabledBackgroundColor:
                      const Color(0xFF6B21A8).withValues(alpha: 0.6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _pdfGenerating ? null : _generatePdfReport,
              )),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              children: [
                _buildChartCard(
                  '📈 Emotion Trend',
                  'Pre-session vs Post-session, split by positive & negative',
                  height: 290,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Legend sits above the chart in a single horizontal
                        // strip so it never competes with the plot for width.
                        // Wrap so the four chips fall to two lines on narrow
                        // tablet widths instead of overflowing on the right.
                        Wrap(
                          spacing: 14,
                          runSpacing: 6,
                          children: [
                            _buildLegendItem('Pre · Positive', cPrePos),
                            _buildLegendItem('Pre · Negative', cPreNeg),
                            _buildLegendItem('Post · Positive', cPostPos),
                            _buildLegendItem('Post · Negative', cPostNeg),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: _emptyChartOverlay(
                            hasData: hasPrePostData,
                            message: 'No pre/post-session data yet this week.',
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: maxEmotionY,
                                minY: 0,
                                groupsSpace: 12,
                                barGroups: emotionTrendGroups,
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchTooltipData: BarTouchTooltipData(
                                    getTooltipColor: (_) =>
                                        const Color(0xFF1F2937),
                                    fitInsideHorizontally: true,
                                    fitInsideVertically: true,
                                    getTooltipItem: (group, gi, rod, ri) {
                                      const labels = [
                                        'Mon',
                                        'Tue',
                                        'Wed',
                                        'Thu',
                                        'Fri',
                                        'Sat',
                                        'Sun'
                                      ];
                                      const kD2D = [1, 2, 3, 4, 5, 6, 0];
                                      final dataIdx = kD2D[group.x];
                                      final phase = ri == 0 ? 'Pre' : 'Post';
                                      final pos = ri == 0
                                          ? prePos[dataIdx]
                                          : postPos[dataIdx];
                                      final neg = ri == 0
                                          ? preNeg[dataIdx]
                                          : postNeg[dataIdx];
                                      return BarTooltipItem(
                                        '${labels[group.x]} · $phase\n'
                                        '+ $pos positive\n'
                                        '− $neg negative',
                                        const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                titlesData: FlTitlesData(
                                  leftTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(
                                          showTitles: false, reservedSize: 6)),
                                  topTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 28,
                                      interval: 1,
                                      getTitlesWidget: (v, _) {
                                        const days = [
                                          'Mon',
                                          'Tue',
                                          'Wed',
                                          'Thu',
                                          'Fri',
                                          'Sat',
                                          'Sun'
                                        ];
                                        final i = v.toInt();
                                        if (i < 0 || i > 6) {
                                          return const SizedBox.shrink();
                                        }
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6),
                                          child: Text(
                                            days[i],
                                            style: _textStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600]!,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  getDrawingHorizontalLine: (_) => FlLine(
                                    color: Colors.grey.withValues(alpha: 0.15),
                                    strokeWidth: 1,
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                              ),
                            ),
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
                // ── Emotion Color Association (3rd) ──
                _buildChartCard(
                  '🎨 Emotion Color Association',
                  'Which colours the child paired the most with each emotion',
                  height: 230,
                  child: _emptyChartOverlay(
                    hasData: hasAssocData,
                    message: 'No emotion-colour pairs yet this week.',
                    child: _buildColorAssociationChart(topAssoc, assocMaxY),
                  ),
                ),
                const SizedBox(height: 14),
                // ── Regulation Trend Chart (4th chart) ───────────────
                _buildChartCard(
                  '🌿 Regulation Trend',
                  'Average sensory zone before vs after sessions per day',
                  height: 280,
                  child: _buildRegulationTrendChart(metrics),
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

  // ── Goals Progress chart ─────────────────────────────────────────
  // A vertical list of progress rows: emoji + label on the left,
  // animated progress bar on the right. Reads from `goals` only — no
  // calls to GoalService here so the past-week (fake) snapshots render
  // correctly through the same code path.
  Widget _buildGoalsProgressChart(List<_GoalSnapshot> goals) {
    if (goals.isEmpty) {
      return const SizedBox.expand();
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: goals.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final g = goals[i];
        final color = Color(g.colorValue);
        final pct =
            g.target == 0 ? 0.0 : (g.current / g.target).clamp(0.0, 1.0);
        return Row(
          children: [
            Text(g.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          g.label,
                          style: _textStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1F2937)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${g.current} / ${g.target}',
                        style: _textStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: g.isCompleted
                                ? const Color(0xFF10B981)
                                : color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 9,
                      backgroundColor: color.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          g.isCompleted ? const Color(0xFF10B981) : color),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Emotion Color Association chart ──────────────────────────────
  // Vertical bar per (emotion, hex) pair. Bar fill colour = the actual
  // colour the child picked, so the chart visually shows the
  // association at a glance. X-axis label shows the emotion name.
  Widget _buildColorAssociationChart(
    List<({String emotion, String hex, int count})> data,
    double maxY,
  ) {
    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY,
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => const Color(0xFF1F2937),
          getTooltipItem: (group, _, rod, __) {
            final pair = data[group.x.toInt()];
            if (pair.count == 0) {
              return BarTooltipItem(
                '${pair.emotion}\nNo data yet',
                const TextStyle(
                  color: Colors.white60,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            }
            final colorName =
                SensoryPalette.fromHex(pair.hex)?.label ?? _humanHex(pair.hex);
            return BarTooltipItem(
              '${pair.emotion}\n$colorName • ${pair.count}×',
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            );
          },
        ),
      ),
      barGroups: data.asMap().entries.map((e) {
        final pair = e.value;
        final hasData = pair.count > 0 && pair.hex.isNotEmpty;
        return BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(
              toY: hasData ? pair.count.toDouble() : 0.3,
              color: hasData
                  ? _hexToColor(pair.hex)
                  : Colors.grey.withValues(alpha: 0.25),
              width: 28,
              borderSide: BorderSide(
                color: hasData
                    ? const Color(0xFFE5E7EB)
                    : Colors.grey.withValues(alpha: 0.15),
                width: 1,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
          ],
        );
      }).toList(),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: Colors.grey.withValues(alpha: 0.15), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (v, _) {
              final idx = v.toInt();
              if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
              final pair = data[idx];
              final hasData = pair.count > 0 && pair.hex.isNotEmpty;
              final colorName = hasData
                  ? (SensoryPalette.fromHex(pair.hex)?.label ?? '')
                  : '';
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pair.emotion,
                      style: _textStyle(
                          fontSize: 13,
                          color: Colors.grey[700]!,
                          fontWeight: FontWeight.w700),
                    ),
                    if (colorName.isNotEmpty)
                      Text(
                        colorName,
                        style: _textStyle(
                            fontSize: 11,
                            color: hasData
                                ? _hexToColor(pair.hex)
                                : Colors.grey[400]!,
                            fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ));
  }

  /// Regulation Trend — line chart showing average pre and post sensory
  /// zone per day. Zone scale: +3 overload → 0 balanced → -2 withdrawal.
  /// Two lines: pre-session (indigo) and post-session (green).
  /// Days with no data are gaps (NaN spots) not zero.
  Widget _buildRegulationTrendChart(_WeekMetrics m) {
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const Color cPre = Color(0xFF6366F1); // indigo — pre-session
    const Color cPost = Color(0xFF10B981); // green  — post-session

    // Build spots — skip NaN days so the line has natural gaps
    // Remap: Mon=0..Sat=5, Sun=6 (display order Mon→Sun)
    const _kDayRemap = [6, 0, 1, 2, 3, 4, 5]; // old index → new display index
    final preSpots = <FlSpot>[];
    final postSpots = <FlSpot>[];
    for (int i = 0; i < 7; i++) {
      final newX = _kDayRemap[i].toDouble();
      if (!m.preZonePerDay[i].isNaN) {
        preSpots.add(FlSpot(newX, m.preZonePerDay[i]));
      }
      if (!m.postZonePerDay[i].isNaN) {
        postSpots.add(FlSpot(newX, m.postZonePerDay[i]));
      }
    }

    final bool hasData = preSpots.isNotEmpty || postSpots.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend + zone labels in same row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  _buildLegendItem('Pre-session zone', cPre),
                  _buildLegendItem('Post-session zone', cPost),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('+3 Overload',
                      style: _textStyle(
                          fontSize: 13,
                          color: Colors.red[300]!,
                          fontWeight: FontWeight.w700)),
                  Text('0 Balanced',
                      style: _textStyle(
                          fontSize: 13,
                          color: Colors.green[400]!,
                          fontWeight: FontWeight.w700)),
                  Text('-2 Withdrawal',
                      style: _textStyle(
                          fontSize: 13,
                          color: Colors.blue[300]!,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Stack(
              children: [
                _emptyChartOverlay(
                  hasData: hasData,
                  message:
                      'No zone data yet. Complete pre & post check-ins to see regulation trend.',
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: 6,
                      minY: -2,
                      maxY: 3,
                      clipData: const FlClipData.all(),
                      lineBarsData: [
                        // Pre-session line
                        LineChartBarData(
                          spots: preSpots,
                          isCurved: true,
                          color: cPre,
                          barWidth: 3,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (_, __, ___, ____) =>
                                FlDotCirclePainter(
                              radius: 5,
                              color: cPre,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: cPre.withValues(alpha: 0.08),
                          ),
                        ),
                        // Post-session line
                        LineChartBarData(
                          spots: postSpots,
                          isCurved: true,
                          color: cPost,
                          barWidth: 3,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (_, __, ___, ____) =>
                                FlDotCirclePainter(
                              radius: 5,
                              color: cPost,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: cPost.withValues(alpha: 0.08),
                          ),
                        ),
                      ],
                      // Horizontal reference line at y=0 (balanced baseline)
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: 0,
                            color: Colors.green.withValues(alpha: 0.4),
                            strokeWidth: 1.5,
                            dashArray: [6, 4],
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.topRight,
                              style: _textStyle(
                                  fontSize: 11, color: Colors.green[400]!),
                              labelResolver: (_) => 'Balanced',
                            ),
                          ),
                        ],
                      ),
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => const Color(0xFF1F2937),
                          getTooltipItems: (spots) {
                            return spots.map((s) {
                              final phase = s.barIndex == 0 ? 'Pre' : 'Post';
                              final zone = s.y.toStringAsFixed(1);
                              final label = s.y >= 2
                                  ? 'Elevated'
                                  : s.y >= 1
                                      ? 'Above baseline'
                                      : s.y >= -0.5
                                          ? 'Balanced'
                                          : s.y >= -1.5
                                              ? 'Low Energy'
                                              : 'Withdrawal';
                              return LineTooltipItem(
                                '$phase · Zone $zone\n$label',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 1,
                            getTitlesWidget: (v, _) {
                              final vi = v.toInt();
                              if (![-2, -1, 0, 1, 2, 3].contains(vi)) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                '$vi',
                                style: _textStyle(
                                    fontSize: 11, color: Colors.grey[500]!),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 1,
                            getTitlesWidget: (v, _) {
                              final i = v.toInt();
                              if (i < 0 || i > 6)
                                return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  dayLabels[i],
                                  style: _textStyle(
                                      fontSize: 12, color: Colors.grey[600]!),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: Colors.grey.withValues(alpha: 0.15),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
          // Header — no action button
          _buildTabHeader(
            '🏆',
            const Color(0xFF22C55E),
            'Rewards',
            "Track your child's reward progress",
          ),
          const SizedBox(height: 20),

          // ── Stats strip: Stars + Rewards Earned ───────────────────
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Text('⭐', style: TextStyle(fontSize: 40)),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$_totalStars',
                              style: _textStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                          Text('Stars Earned',
                              style: _textStyle(
                                  fontSize: 15,
                                  color: Colors.white.withValues(alpha: 0.85))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Text('🎁', style: TextStyle(fontSize: 40)),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$_rewardsUnlocked',
                              style: _textStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                          Text('Rewards Earned',
                              style: _textStyle(
                                  fontSize: 15,
                                  color: Colors.white.withValues(alpha: 0.85))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Earned Rewards | Rewards to Unlock ───────────────────
          Expanded(
            child: FutureBuilder<List<ChildReward>>(
              future: ChildRewardsService.getAllRewards(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snapshot.data!;
                final earned = all.where((r) => r.unlockedAt != null).toList()
                  ..sort((a, b) => b.unlockedAt!.compareTo(a.unlockedAt!));
                final remaining =
                    all.where((r) => r.unlockedAt == null).toList();

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildCard(
                        'Earned Rewards',
                        Icons.emoji_events_rounded,
                        earned.isEmpty
                            ? Container(
                                alignment: Alignment.center,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 60),
                                child: Text(
                                  'No rewards yet — earn stars to unlock!',
                                  textAlign: TextAlign.center,
                                  style: _textStyle(
                                      fontSize: 16, color: Colors.grey[400]!),
                                ),
                              )
                            : _buildRewardGrid(earned),
                        titleColor: const Color(0xFF6B21A8),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildCard(
                        'Rewards to Unlock',
                        Icons.lock_outline_rounded,
                        remaining.isEmpty
                            ? Container(
                                alignment: Alignment.center,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 60),
                                child: Text(
                                  '🎉 All rewards unlocked!',
                                  textAlign: TextAlign.center,
                                  style: _textStyle(
                                      fontSize: 16, color: Colors.green[400]!),
                                ),
                              )
                            : _buildRewardGrid(remaining, locked: true),
                        titleColor: const Color(0xFF6B21A8),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardGrid(List<ChildReward> rewards, {bool locked = false}) {
    final rows = <Widget>[];

    for (int i = 0; i < rewards.length; i += 2) {
      rows.add(
        Row(
          children: [
            Expanded(
              child: _buildRewardChip(
                rewards[i].emoji,
                rewards[i].title,
                !locked,
                locked ? rewards[i].milestoneStars : null,
              ),
            ),
            const SizedBox(width: 14),
            if (i + 1 < rewards.length)
              Expanded(
                child: _buildRewardChip(
                  rewards[i + 1].emoji,
                  rewards[i + 1].title,
                  !locked,
                  locked ? rewards[i + 1].milestoneStars : null,
                ),
              )
            else
              const Expanded(child: SizedBox()),
          ],
        ),
      );

      if (i + 2 < rewards.length) {
        rows.add(const SizedBox(height: 10));
      }
    }

    return Column(children: rows);
  }

  Widget _buildRewardChip(
    String emoji,
    String label,
    bool earned, [
    int? requiredStars,
  ]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: earned ? const Color(0xFFFFF3E0) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: earned ? Colors.orange.shade300 : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: _textStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  earned
                      ? 'Earned ✓'
                      : requiredStars != null
                          ? 'Unlock at $requiredStars ⭐'
                          : 'Locked',
                  style: _textStyle(
                    fontSize: 13,
                    color: earned ? Colors.green : const Color(0xFFD97706),
                    fontWeight: FontWeight.w600,
                  ),
                ),
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

  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTabHeader(
            '⚙️',
            const Color(0xFF3B82F6),
            'Settings',
            'Manage your account and preferences',
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
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
                children: [
                  // Row 1
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                            child: _buildSettingsTile(Icons.edit,
                                'Edit Profile', 'Update your name and avatar',
                                onTap: () => _showEditProfileDialog())),
                        VerticalDivider(
                            color: Colors.grey[200], thickness: 1, width: 1),
                        Expanded(
                            child: _buildSettingsTile(
                                Icons.lock_outline,
                                'Change Email & Password',
                                'Update your login credentials',
                                onTap: () => _showChangePasswordDialog())),
                      ],
                    ),
                  ),
                  Divider(color: Colors.grey[200], thickness: 1, height: 1),
                  // Row 2
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                            child: _buildSettingsTile(
                                Icons.refresh_rounded,
                                'Reset Game Data',
                                'Reset stars, rewards & analytics',
                                iconColor: Colors.orange,
                                onTap: () => _showResetGameDialog())),
                        VerticalDivider(
                            color: Colors.grey[200], thickness: 1, width: 1),
                        Expanded(
                            child: _buildSettingsTile(
                                Icons.delete_forever,
                                'Deactivate Account',
                                'Permanently deactivate your account',
                                iconColor: Colors.red,
                                onTap: () => _showDeactivateConfirmDialog())),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    final color = iconColor ?? const Color(0xFF6B21A8);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 48),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: _textStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: _textStyle(
                  fontSize: 18,
                  color: Colors.grey[500]!,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF6B21A8), size: 28),
          ),
          const SizedBox(width: 14),
          Text(
            title,
            style: _textStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF6B21A8),
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
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? const Color(0xFF6B21A8), size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: _textStyle(
                          fontSize: 22, fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: _textStyle(
                          fontSize: 17,
                          color: Colors.grey[500]!,
                          fontWeight: FontWeight.w400)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow(IconData icon, String title, String subtitle,
      bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6B21A8), size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        _textStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: _textStyle(
                        fontSize: 17,
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

  /// Standardised status banner used across the Settings actions.
  /// Green for success, red for errors — consistent rounded floating style.
  void _showStatusSnack(String message, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(success ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message,
                    style: _textStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          backgroundColor:
              success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _showEditProfileDialog() async {
    if (!mounted) return;

    final nameCtrl = TextEditingController(text: _childName);
    final ageCtrl =
        TextEditingController(text: _childAge != null ? '$_childAge' : '');
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
            onPressed: () async {
              debugPrint('SETTINGS childUserId = $_childUserId');
              final newName = nameCtrl.text.trim();
              final newAge = int.tryParse(ageCtrl.text.trim());

              // Build the DB diff BEFORE mutating local state, otherwise the
              // "changed?" comparison always fails and nothing is written.
              final updates = <String, dynamic>{};
              if (newName.isNotEmpty && newName != _childName) {
                updates['full_name'] = newName;
              }
              if (newAge != null && newAge != _childAge) {
                final now = DateTime.now();
                final dob = DateTime(now.year - newAge, now.month, now.day);
                updates['date_of_birth'] = dob.toIso8601String().split('T')[0];
              }

              bool saved = false;
              final caregiverId = Supabase.instance.client.auth.currentUser?.id;
              if (caregiverId != null &&
                  _childUserId != null &&
                  updates.isNotEmpty) {
                try {
                  final count = await Supabase.instance.client.rpc(
                    'update_child_profile',
                    params: {
                      'p_caregiver_id': caregiverId,
                      'p_child_user_id': _childUserId,
                      'p_full_name':
                          updates['full_name'], // null when name unchanged
                      'p_date_of_birth':
                          updates['date_of_birth'], // null when age unchanged
                    },
                  );
                  final rows =
                      (count is int) ? count : int.tryParse('$count') ?? 0;
                  debugPrint('EDIT rpc rows=$rows');
                  saved = rows > 0;
                } catch (e) {
                  debugPrint('Profile update RPC error: $e');
                }
              }

              // Reflect the change locally so this dashboard updates instantly.
              if (mounted) {
                setState(() {
                  if (newName.isNotEmpty) _childName = newName;
                  if (newAge != null) _childAge = newAge;
                });
              }

              if (context.mounted) Navigator.pop(ctx);
              if (updates.isEmpty) {
                _showStatusSnack('No changes to save.', success: true);
              } else if (saved) {
                _showStatusSnack('Profile updated!');
              } else {
                _showStatusSnack('Could not save changes.', success: false);
              }
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
    final emailCtrl = TextEditingController(
        text: Supabase.instance.client.auth.currentUser?.email ?? '');
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Change Email & Password',
            style: _textStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPassCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPassCtrl,
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
            onPressed: () async {
              final newEmail = emailCtrl.text.trim();
              final newPass = newPassCtrl.text.trim();
              final confirmPass = confirmPassCtrl.text.trim();

              if (newPass.isNotEmpty && newPass != confirmPass) {
                _showStatusSnack('Passwords do not match.', success: false);
                return;
              }

              try {
                final currentEmail =
                    Supabase.instance.client.auth.currentUser?.email ?? '';
                final emailChanged =
                    newEmail.isNotEmpty && newEmail != currentEmail;
                final passwordChanged = newPass.isNotEmpty;

                if (!emailChanged && !passwordChanged) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showStatusSnack('No changes to save.');
                  return;
                }

                // Suppress the global auth listener for the userUpdated event
                // this local call fires (otherwise it would treat it as an
                // email-change confirmation deep link).
                AuthService.ignoreNextUserUpdated = true;
                await Supabase.instance.client.auth.updateUser(
                  UserAttributes(
                    email: emailChanged ? newEmail : null,
                    password: passwordChanged ? newPass : null,
                  ),
                  // Same deep link registration uses, so the confirmation
                  // link opens EMOLOR and returns the user to the login page.
                  emailRedirectTo:
                      emailChanged ? 'emolor://login-callback/' : null,
                );

                if (ctx.mounted) Navigator.pop(ctx);
                _showStatusSnack(emailChanged
                    ? 'Updated! Check your new email to confirm, then log in.'
                    : 'Password updated! Please log in.');

                // Sign out and return to login (mirrors the registration /
                // verification flow). Brief delay lets the green banner show,
                // then we explicitly clear it before navigating — otherwise a
                // floating SnackBar gets orphaned by the route swap and stays
                // stuck on the login page.
                await Supabase.instance.client.auth.signOut();
                if (mounted) {
                  await Future.delayed(const Duration(milliseconds: 1600));
                  if (mounted) {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    context.go('/login');
                  }
                }
              } catch (e) {
                AuthService.ignoreNextUserUpdated = false;
                _showStatusSnack('Error: ${e.toString()}', success: false);
              }
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
                _showStatusSnack('Game data has been reset to zero.');
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
            "This will permanently remove ${_childName.isNotEmpty && _childName != 'Child' ? '$_childName\'s' : "this child's"} profile and all related access. This action cannot be undone.\n\nAre you sure you want to proceed?",
            style: _textStyle(fontSize: 17, color: Colors.grey[700]!)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: _textStyle(fontSize: 16, color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              debugPrint('SETTINGS childUserId = $_childUserId');
              Navigator.pop(ctx);
              // Remove THIS child's profile link from the current caregiver,
              // then return to the "Who's Playing Today?" selection page.
              // (Do NOT sign the caregiver out.)
              bool deleted = false;
              try {
                final caregiverId =
                    Supabase.instance.client.auth.currentUser?.id;
                if (caregiverId != null &&
                    _childUserId != null &&
                    _childUserId!.isNotEmpty) {
                  final result = await Supabase.instance.client
                      .rpc('delete_child_profile', params: {
                    'p_caregiver_id': caregiverId,
                    'p_child_user_id': _childUserId,
                  });
                  final count = (result is int)
                      ? result
                      : int.tryParse(result.toString()) ?? 0;
                  deleted = count > 0;

                  // Clear the locally-selected profile so the next screen
                  // doesn't keep pointing at the deleted child.
                  final selected =
                      await ChildSessionService.getChildProfileId();
                  if (selected == _childUserId) {
                    await ChildSessionService.saveChildProfileId('');
                  }
                }
              } catch (e) {
                debugPrint('Deactivate (delete child) error: $e');
              }
              if (mounted) {
                _showStatusSnack(
                    deleted ? 'Profile removed.' : 'Could not remove profile.',
                    success: deleted);
                await Future.delayed(const Duration(milliseconds: 1200));
                if (mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  context.go('/orgz-child-dashboard');
                }
              }
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
  'Happy', 'Excited', 'Calm', 'Loved',
  // Legacy names
  'Joy', 'Trust',
};

const Set<String> _kNegativeEmotions = {
  'Sad', 'Angry', 'Scared', 'Tired',
  // Legacy names
  'Fear', 'Sadness', 'Disgust', 'Anger', 'Disgusted',
};

/// All numbers that drive a single week's worth of charts.
///
///   • [emotionFreq]      name → count, used by Distribution chart.
///   • [positivePerDay]   index 0=Sun … 6=Sat (legacy — kept for AI prompt).
///   • [negativePerDay]   index 0=Sun … 6=Sat (legacy — kept for AI prompt).
///   • [sessionsPerDay]   index 0=Mon … 6=Sun (per-day session count).
///   • [gameMinutes]      raw activity id → minutes (kept for AI prompt).
///   • [preEmotionFreq]   name → count of pre-session emotions logged.
///   • [postEmotionFreq]  name → count of post-session emotions logged.
///   • [prePerDay]        per-day pre-session emotion count, index 0=Sun…6=Sat.
///   • [postPerDay]       per-day post-session emotion count, index 0=Sun…6=Sat.
///   • [colorByEmotion]   emotion name → (colour hex → count) — drives the
///                        Emotion Color Association chart.
///   • [goals]            list of active goals + their current/target progress
///                        for the Goals Progress chart and Goals Completed card.
///   • [starsEarned]      sum of stars earned from completions in this week.
///   • [totalSessions]    count of fully-completed child_sessions (both pre
///                        AND post recorded) — for Total Sessions card.
///
/// All counters default to zero/empty so a missing offset still renders a
/// clean empty state.
class _WeekMetrics {
  final Map<String, int> emotionFreq;
  final List<int> positivePerDay;
  final List<int> negativePerDay;
  final List<int> sessionsPerDay;
  final Map<String, int> gameMinutes;
  // Raw activity time in seconds — used for Top Activity comparison so that
  // short sessions (< 30 s) are not rounded down to 0 min and hidden.
  // Keyed by activityName, same validActivities filter as gameMinutes.
  final Map<String, int> gameSeconds;

  // ── New fields for the corrected analytics ──────────────────────────
  final Map<String, int> preEmotionFreq;
  final Map<String, int> postEmotionFreq;
  final List<int> prePerDay;
  final List<int> postPerDay;
  // Per-day pre/post split into positive vs negative emotion counts. Drives
  // the stacked-grouped Emotion Trend bar chart in the Progress tab.
  // index 0 = Sun … 6 = Sat.
  final List<int> prePositivePerDay;
  final List<int> preNegativePerDay;
  final List<int> postPositivePerDay;
  final List<int> postNegativePerDay;
  final Map<String, Map<String, int>> colorByEmotion;
  final List<_GoalSnapshot> goals;
  final int starsEarned;
  final int totalSessions;

  // ── Sensory Zone & Regulation Tracking ───────────────────────────────
  // Per-session regulation deltas (pre_zone - post_zone). Positive = calming.
  final List<int> regulationDeltas;
  // How many sessions this week showed a sensory mismatch flag.
  final int mismatchCount;
  // Per-day average pre and post zone values (for Progress tab chart).
  // index 0 = Sun … 6 = Sat. NaN means no data that day.
  final List<double> preZonePerDay;
  final List<double> postZonePerDay;

  const _WeekMetrics({
    this.emotionFreq = const {},
    this.positivePerDay = const [0, 0, 0, 0, 0, 0, 0],
    this.negativePerDay = const [0, 0, 0, 0, 0, 0, 0],
    this.sessionsPerDay = const [0, 0, 0, 0, 0, 0, 0],
    this.gameMinutes = const {},
    this.gameSeconds = const {},
    this.preEmotionFreq = const {},
    this.postEmotionFreq = const {},
    this.prePerDay = const [0, 0, 0, 0, 0, 0, 0],
    this.postPerDay = const [0, 0, 0, 0, 0, 0, 0],
    this.prePositivePerDay = const [0, 0, 0, 0, 0, 0, 0],
    this.preNegativePerDay = const [0, 0, 0, 0, 0, 0, 0],
    this.postPositivePerDay = const [0, 0, 0, 0, 0, 0, 0],
    this.postNegativePerDay = const [0, 0, 0, 0, 0, 0, 0],
    this.colorByEmotion = const {},
    this.goals = const [],
    this.starsEarned = 0,
    this.totalSessions = 0,
    this.regulationDeltas = const [],
    this.mismatchCount = 0,
    this.preZonePerDay = const [
      double.nan,
      double.nan,
      double.nan,
      double.nan,
      double.nan,
      double.nan,
      double.nan,
    ],
    this.postZonePerDay = const [
      double.nan,
      double.nan,
      double.nan,
      double.nan,
      double.nan,
      double.nan,
      double.nan,
    ],
  });
}

// Fake week data removed — all analytics are real data only.

/// One row of the Goals Progress chart.
class _GoalSnapshot {
  final String label;
  final int current;
  final int target;
  final String emoji;
  final int colorValue;

  const _GoalSnapshot({
    required this.label,
    required this.current,
    required this.target,
    required this.emoji,
    required this.colorValue,
  });

  bool get isCompleted => current >= target;
}
