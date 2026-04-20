import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/emotion_journal_service.dart';
import '../core/services/emotion_service.dart';
import '../core/services/star_service.dart';
import '../features/child/domain/models/emotion.dart';
import '../features/caregiver/presentation/widgets/new_goal_dialog.dart';
import '../features/caregiver/services/goal_service.dart';
import '../features/child/services/child_rewards_service.dart';
import '../features/child/services/completion_service.dart';
import '../features/child/models/completion_record.dart';

// ── Per-game stat model ───────────────────────────────────────────────
class _GameStat {
  final int plays;
  final double avgStars;
  final double avgScore; // 0–100
  final double avgSeconds;
  const _GameStat({
    required this.plays,
    required this.avgStars,
    required this.avgScore,
    required this.avgSeconds,
  });
}

// ── Dashboard ─────────────────────────────────────────────────────────
class CaregiverDashboard extends StatefulWidget {
  final String? childName;
  final bool showSwitchAccount;
  const CaregiverDashboard({
    super.key,
    this.childName,
    this.showSwitchAccount = false,
  });
  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // ── Nav ───────────────────────────────────────────────────────────
  int _navIdx = 0;

  // ── Profile ───────────────────────────────────────────────────────
  String _centreName = 'Centre';
  late String _childName;
  String _childAvatar = '🐱';
  late AnimationController _glow;

  // ── Analytics state ───────────────────────────────────────────────
  bool _loading = true;

  // Overview / Rewards
  int _totalStars = 0;
  int _rewardsUnlocked = 0;
  int _totalActivities = 0;
  int _todayActivities = 0;
  int _weekExpressions = 0;
  List<CompletionRecord> _recentCompletions = [];
  List<Map<String, dynamic>> _activeGoals = [];

  // Emotions
  Map<String, int> _emotionFreq = {};
  Map<String, Map<String, int>> _dailyBreakdown = {};
  List<Map<String, dynamic>> _allJournal = [];

  // Games
  Map<String, _GameStat> _gameStats = {};
  Map<String, int> _gameFreq = {};

  // My Colours personalisation
  List<Emotion> _emotionPalette = [];

  // Settings
  bool _rewardAlerts = true;
  bool _sessionReminders = false;

  // ── Emotion metadata (Plutchik 8) ─────────────────────────────────
  static const _emotionEmoji = {
    'Joy': '😊', 'Trust': '🤝', 'Fear': '😨', 'Surprise': '😲',
    'Sadness': '😢', 'Disgust': '🤢', 'Anger': '😠', 'Anticipation': '🤩',
    // Express-card names
    'Happy': '😄', 'Sad': '😢', 'Angry': '😠', 'Scared': '😨',
    'Excited': '🤩', 'Calm': '😌', 'Tired': '😴', 'Loved': '🥰',
    'Confused': '😕', 'Proud': '😤', 'Shy': '😳', 'Silly': '🤪',
  };

  static const _emotionColor = {
    'Joy': Color(0xFFFFE66D), 'Trust': Color(0xFF7ED957),
    'Fear': Color(0xFFBB6BD9), 'Surprise': Color(0xFF06B6D4),
    'Sadness': Color(0xFF74B9FF), 'Disgust': Color(0xFF84CC16),
    'Anger': Color(0xFFEF4444), 'Anticipation': Color(0xFFFF9F43),
    'Happy': Color(0xFF34D399), 'Sad': Color(0xFF60A5FA),
    'Angry': Color(0xFFEF4444), 'Scared': Color(0xFFBB6BD9),
    'Excited': Color(0xFFFF9F43), 'Calm': Color(0xFF06B6D4),
  };

  static const _positiveSet = {
    'Joy', 'Trust', 'Surprise', 'Anticipation', 'Happy', 'Excited', 'Calm',
    'Loved', 'Proud',
  };

  static const _gameEmoji = {
    'EMOZZLE': '🧩', 'EMOPOP': '🫧', 'EMOSPELL': '🔤', 'EMOSORT': '📋',
    'EMOSLASH': '⚔️', 'EMOCATCH': '🎯', 'Draw': '🖌️',
    'Express Cards': '🗣️', 'My Colours': '🎨',
  };

  static const _gameColor = {
    'EMOZZLE': Color(0xFF7C3AED), 'EMOPOP': Color(0xFF2563EB),
    'EMOSPELL': Color(0xFF059669), 'EMOSORT': Color(0xFFD97706),
    'EMOSLASH': Color(0xFFDC2626), 'EMOCATCH': Color(0xFF0891B2),
    'Draw': Color(0xFFDB2777), 'Express Cards': Color(0xFF4338CA),
    'My Colours': Color(0xFFCA8A04),
  };

  static const _defaultPaletteColors = {
    'joy': Color(0xFFFFE66D), 'trust': Color(0xFF7ED957),
    'fear': Color(0xFFBB6BD9), 'surprise': Color(0xFF06B6D4),
    'sadness': Color(0xFF74B9FF), 'disgust': Color(0xFF84CC16),
    'anger': Color(0xFFEF4444), 'anticipation': Color(0xFFFF9F43),
  };

  // ── Lifecycle ─────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _childName = widget.childName ?? 'Child';
    _glow = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    WidgetsBinding.instance.addObserver(this);
    _loadAll();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _glow.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────
  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      await Future.wait([
        _loadProfile(),
        _loadAnalytics(),
        _loadEmotionPalette(),
      ]);
    } catch (e) {
      debugPrint('Dashboard load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadProfile() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final p = await Supabase.instance.client
          .from('profiles').select('full_name, avatar_url')
          .eq('user_id', uid).maybeSingle();
      if (mounted && p != null) {
        setState(() {
          final n = p['full_name'] as String?;
          if (n != null && n.isNotEmpty) _centreName = n;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadEmotionPalette() async {
    final palette = await EmotionService.loadEmotionsStatic();
    if (mounted) setState(() => _emotionPalette = palette);
  }

  Future<void> _loadAnalytics() async {
    final results = await Future.wait([
      StarService.getTotalStars(),
      ChildRewardsService.getUnlockedCount(),
      CompletionService.history(),
      EmotionJournalService.getEmotionFrequency(),
      EmotionJournalService.getGameFrequency(),
      EmotionJournalService.getEntries(),
      EmotionJournalService.getDailyBreakdown(days: 28),
      GoalService.getAllGoals(),
    ]);

    final stars = results[0] as int;
    final rewards = results[1] as int;
    final completions = results[2] as List<CompletionRecord>;
    final emotionFreq = results[3] as Map<String, int>;
    final gameFreq = results[4] as Map<String, int>;
    final journal = results[5] as List<Map<String, dynamic>>;
    final daily = results[6] as Map<String, Map<String, int>>;
    final goals = results[7] as List<PerformanceGoal>;

    // Per-game stats from completion records
    final byGame = <String, List<CompletionRecord>>{};
    for (final r in completions) {
      byGame.putIfAbsent(r.activityName, () => []).add(r);
    }
    final gStats = <String, _GameStat>{};
    byGame.forEach((name, recs) {
      final avgStars = recs.map((r) => r.starsEarned).reduce((a, b) => a + b) / recs.length;
      final scored = recs.where((r) => r.scoreMax > 0).toList();
      final avgScore = scored.isEmpty ? 0.0
          : scored.map((r) => r.scoreValue / r.scoreMax * 100).reduce((a, b) => a + b) / scored.length;
      final avgSec = recs.map((r) => r.timeSpentSeconds).reduce((a, b) => a + b) / recs.length;
      gStats[name] = _GameStat(plays: recs.length, avgStars: avgStars, avgScore: avgScore, avgSeconds: avgSec);
    });

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekAgo = now.subtract(const Duration(days: 7));
    final todayCount = completions.where((c) => c.completedAt.isAfter(todayStart)).length;
    final weekExpr = journal.where((e) {
      final ts = DateTime.tryParse(e['timestamp'] as String? ?? '');
      return ts != null && ts.isAfter(weekAgo);
    }).length;

    if (mounted) {
      setState(() {
        _totalStars = stars;
        _rewardsUnlocked = rewards;
        _totalActivities = completions.length;
        _todayActivities = todayCount;
        _weekExpressions = weekExpr;
        _recentCompletions = completions.take(6).toList();
        _emotionFreq = emotionFreq;
        _gameFreq = gameFreq;
        _gameStats = gStats;
        _dailyBreakdown = daily;
        _allJournal = journal;
        _activeGoals = goals.map((g) => <String, dynamic>{
          'id': g.id,
          'label': '${g.category.label} — ${g.target} ${g.duration.label}',
          'progress': g.progressFraction,
          'current': g.currentProgress,
          'target': g.target,
          'emoji': g.category.emoji,
        }).toList();
      });
    }
  }

  // ── Derived helpers ───────────────────────────────────────────────
  double get _positiveRatio {
    if (_emotionFreq.isEmpty) return 0;
    final pos = _emotionFreq.entries.where((e) => _positiveSet.contains(e.key)).fold(0, (s, e) => s + e.value);
    final total = _emotionFreq.values.fold(0, (s, v) => s + v);
    return total > 0 ? pos / total : 0;
  }

  String get _topEmotion => _emotionFreq.isEmpty ? '–'
      : _emotionFreq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

  String get _mostPlayedGame => _gameStats.isEmpty ? '–'
      : _gameStats.entries.reduce((a, b) => a.value.plays >= b.value.plays ? a : b).key;

  String get _bestScoringGame {
    final s = _gameStats.entries.where((e) => e.value.avgScore > 0).toList();
    return s.isEmpty ? '–' : s.reduce((a, b) => a.value.avgScore >= b.value.avgScore ? a : b).key;
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  Map<String, Map<String, int>> get _timeOfDay {
    final r = {'Morning 6–12': <String, int>{}, 'Afternoon 12–18': <String, int>{}, 'Evening 18–22': <String, int>{}};
    for (final e in _allJournal) {
      final ts = DateTime.tryParse(e['timestamp'] as String? ?? '')?.toLocal();
      if (ts == null) continue;
      final slot = ts.hour >= 6 && ts.hour < 12 ? 'Morning 6–12'
          : ts.hour >= 12 && ts.hour < 18 ? 'Afternoon 12–18'
          : ts.hour >= 18 && ts.hour < 22 ? 'Evening 18–22' : '';
      if (slot.isEmpty) continue;
      final emotion = e['emotion'] as String? ?? 'Unknown';
      r[slot]![emotion] = (r[slot]![emotion] ?? 0) + 1;
    }
    return r;
  }

  // ── Text style helper ─────────────────────────────────────────────
  TextStyle _ts({double sz = 15, FontWeight fw = FontWeight.w600, Color? color}) =>
      GoogleFonts.baloo2(fontSize: sz, fontWeight: fw, color: color ?? Colors.black87);

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFF8FAFC), Color(0xFFEDE9FE)],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              _sidebar(),
              Expanded(child: _loading ? _loadingView() : _content()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loadingView() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const CircularProgressIndicator(color: Color(0xFF6B21A8)),
      const SizedBox(height: 12),
      Text('Loading analytics…', style: _ts(sz: 16, color: Colors.grey[600]!)),
    ]),
  );

  // ─────────────────────────────────────────────────────────────────
  // SIDEBAR
  // ─────────────────────────────────────────────────────────────────
  Widget _sidebar() {
    final items = [
      (Icons.home_rounded, 'Overview'),
      (Icons.favorite_rounded, 'Emotions'),
      (Icons.sports_esports_rounded, 'Games'),
      (Icons.emoji_events_rounded, 'Rewards'),
      (Icons.settings_rounded, 'Settings'),
    ];
    return Container(
      width: 270,
      decoration: const BoxDecoration(
        color: Color(0xFF6B21A8),
        boxShadow: [BoxShadow(color: Color(0x4D9333EA), blurRadius: 20)],
      ),
      child: SafeArea(
        child: Column(children: [
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _glow,
            builder: (_, __) => Text('EMOLOR',
              style: GoogleFonts.fredoka(
                fontSize: 48, fontWeight: FontWeight.w700, color: Colors.white,
                shadows: [Shadow(
                  color: Colors.white.withValues(alpha: 0.5 + _glow.value * 0.5),
                  blurRadius: 8 + _glow.value * 14,
                )],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('CENTRE PORTAL',
              style: _ts(sz: 11, color: Colors.white70, fw: FontWeight.w500)),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: items.asMap().entries.map((e) => _navItem(
                e.value.$1, e.value.$2, e.key,
              )).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: InkWell(
              onTap: () {
                if (widget.showSwitchAccount) {
                  context.go('/child/home', extra: {'showSwitch': true, 'childName': _childName});
                } else {
                  context.go('/child/home');
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade300.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text('Child Dashboard',
                    style: _ts(sz: 14, color: Colors.white, fw: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int idx) {
    final active = _navIdx == idx;
    return GestureDetector(
      onTap: () {
        if (idx == 0) _loadAll();
        setState(() => _navIdx = idx);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: active ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 10),
          Text(label, style: _ts(sz: 18, color: Colors.white,
            fw: active ? FontWeight.w700 : FontWeight.w500)),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // CONTENT ROUTER
  // ─────────────────────────────────────────────────────────────────
  Widget _content() {
    switch (_navIdx) {
      case 1: return _emotionsTab();
      case 2: return _gamesTab();
      case 3: return _rewardsTab();
      case 4: return _settingsTab();
      default: return _overviewTab();
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // TAB 0 — OVERVIEW
  // ─────────────────────────────────────────────────────────────────
  Widget _overviewTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Overview', style: _ts(sz: 28, fw: FontWeight.w700, color: const Color(0xFF6B21A8))),
            Text("$_childName's emotional learning summary",
              style: _ts(sz: 15, color: Colors.grey[600]!)),
          ]),
          _childBadge(),
        ]),
        const SizedBox(height: 14),

        // Stat cards
        Row(children: [
          _statCard('⭐', 'Stars', '$_totalStars', Colors.orange, 'Total earned'),
          const SizedBox(width: 10),
          _statCard('🎮', 'Today', '$_todayActivities', Colors.blue, 'Games played'),
          const SizedBox(width: 10),
          _statCard('💬', 'Emotions', '$_weekExpressions', Colors.purple, 'This week'),
          const SizedBox(width: 10),
          _statCard('🏅', 'Rewards', '$_rewardsUnlocked', Colors.green, 'Unlocked'),
        ]),
        const SizedBox(height: 14),

        // Main content
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Left col — recent games + emotion snapshot
            Expanded(flex: 3, child: Column(children: [
              Expanded(flex: 3, child: _card('Recent Games', Icons.history_rounded,
                _buildRecentGames())),
              const SizedBox(height: 12),
              Expanded(flex: 2, child: _card('Top Emotions This Week',
                Icons.insights_rounded, _buildTopEmotionBars(5))),
            ])),
            const SizedBox(width: 12),
            // Right col — emotional state + my colours
            Expanded(flex: 2, child: Column(children: [
              _card('Emotional State', Icons.psychology_rounded,
                _buildEmotionalState()),
              const SizedBox(height: 12),
              Expanded(child: _card('My Colours Status', Icons.palette_rounded,
                _buildColoursStatus())),
            ])),
          ]),
        ),
      ]),
    );
  }

  Widget _childBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.purple.withValues(alpha: 0.1), blurRadius: 10)],
    ),
    child: Row(children: [
      Text(_childAvatar, style: const TextStyle(fontSize: 26)),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_childName, style: _ts(sz: 15, fw: FontWeight.w700)),
        Text('$_totalActivities sessions total', style: _ts(sz: 12, color: Colors.grey[500]!)),
      ]),
    ]),
  );

  Widget _buildRecentGames() {
    if (_recentCompletions.isEmpty) {
      return Center(child: Text('No games played yet',
        style: _ts(sz: 14, color: Colors.grey[400]!)));
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentCompletions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 7),
      itemBuilder: (_, i) {
        final c = _recentCompletions[i];
        final emoji = _gameEmoji[c.activityName] ?? '🎮';
        final color = _gameColor[c.activityName] ?? Colors.blue;
        final pct = c.scoreMax > 0 ? ((c.scoreValue / c.scoreMax) * 100).round() : 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.activityName, style: _ts(sz: 15, fw: FontWeight.w700)),
              Text('Score: $pct%  ·  ${(c.timeSpentSeconds / 60).toStringAsFixed(1)} min',
                style: _ts(sz: 12, color: Colors.grey[500]!)),
            ])),
            Row(children: List.generate(3, (s) => Icon(
              s < c.starsEarned ? Icons.star_rounded : Icons.star_outline_rounded,
              color: Colors.orange, size: 17,
            ))),
            const SizedBox(width: 6),
            Text(_timeAgo(c.completedAt), style: _ts(sz: 11, color: Colors.grey[400]!)),
          ]),
        );
      },
    );
  }

  Widget _buildTopEmotionBars(int count) {
    if (_emotionFreq.isEmpty) {
      return Center(child: Text('No emotion data yet — start playing!',
        style: _ts(sz: 13, color: Colors.grey[400]!)));
    }
    final total = _emotionFreq.values.fold(0, (s, v) => s + v);
    final sorted = _emotionFreq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: sorted.take(count).map((e) {
        final pct = total > 0 ? e.value / total : 0.0;
        final color = _emotionColor[e.key] ?? Colors.grey;
        final emoji = _emotionEmoji[e.key] ?? '😊';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            SizedBox(width: 78, child: Text(e.key, style: _ts(sz: 13, fw: FontWeight.w600),
              overflow: TextOverflow.ellipsis)),
            Expanded(child: Stack(children: [
              Container(height: 10, decoration: BoxDecoration(
                color: Colors.grey[200], borderRadius: BorderRadius.circular(5))),
              FractionallySizedBox(
                widthFactor: pct.clamp(0.0, 1.0),
                child: Container(height: 10, decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(5))),
              ),
            ])),
            const SizedBox(width: 6),
            Text('${(pct * 100).round()}%',
              style: _ts(sz: 12, color: color, fw: FontWeight.w700)),
          ]),
        );
      }).toList(),
    );
  }

  Widget _buildEmotionalState() {
    final top = _topEmotion;
    final emoji = _emotionEmoji[top] ?? '😊';
    final topColor = _emotionColor[top] ?? Colors.grey;
    final ratio = _positiveRatio;
    final explored = _emotionFreq.keys.length;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _emotionStateCol(emoji, top, 'Most felt', topColor),
      Container(width: 1, height: 50, color: Colors.grey[200]),
      _emotionStateCol('${(ratio * 100).round()}%',
        ratio >= 0.5 ? 'Positive' : 'Mixed', 'Mood ratio',
        ratio >= 0.5 ? Colors.green : Colors.orange),
      Container(width: 1, height: 50, color: Colors.grey[200]),
      _emotionStateCol('$explored', 'Emotions', 'Explored', Colors.blue),
    ]);
  }

  Widget _emotionStateCol(String top, String mid, String bot, Color color) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(top, style: _ts(sz: top.length <= 3 ? 26 : 20, fw: FontWeight.w700, color: color)),
      Text(mid, style: _ts(sz: 13, fw: FontWeight.w600)),
      Text(bot, style: _ts(sz: 11, color: Colors.grey[500]!)),
    ]);
  }

  Widget _buildColoursStatus() {
    if (_emotionPalette.isEmpty) {
      return Center(child: Text('Loading…', style: _ts(sz: 13, color: Colors.grey[400]!)));
    }
    int personalised = 0;
    for (final e in _emotionPalette) {
      final def = _defaultPaletteColors[e.id];
      if (def != null && e.color.toARGB32() != def.toARGB32()) personalised++;
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Expanded(child: _miniStat('$personalised / 8', 'Colours set', Colors.purple)),
        const SizedBox(width: 8),
        Expanded(child: _miniStat('${8 - personalised}', 'Still default', Colors.grey)),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 6, runSpacing: 6, children: _emotionPalette.map<Widget>((e) {
        final def = _defaultPaletteColors[e.id];
        final isCustom = def != null && e.color.toARGB32() != def.toARGB32();
        return Tooltip(
          message: '${e.name} ${isCustom ? "(custom)" : "(default)"}',
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: e.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isCustom ? Colors.purple : Colors.grey.shade300,
                width: isCustom ? 2.5 : 1,
              ),
            ),
            child: Center(child: Text(e.emoji,
              style: const TextStyle(fontSize: 14))),
          ),
        );
      }).toList()),
    ]);
  }

  Widget _miniStat(String val, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(val, style: _ts(sz: 20, fw: FontWeight.w700, color: color)),
      Text(label, style: _ts(sz: 11, color: Colors.grey[600]!)),
    ]),
  );

  // ─────────────────────────────────────────────────────────────────
  // TAB 1 — EMOTIONS
  // ─────────────────────────────────────────────────────────────────
  Widget _emotionsTab() {
    final total = _emotionFreq.values.fold(0, (s, v) => s + v);
    final ratio = _positiveRatio;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Emotion Analytics', style: _ts(sz: 28, fw: FontWeight.w700, color: const Color(0xFF6B21A8))),
        Text("Understanding $_childName's emotional patterns",
          style: _ts(sz: 15, color: Colors.grey[600]!)),
        const SizedBox(height: 14),

        Row(children: [
          _statCard('💬', 'Total', '$total', Colors.purple, 'Interactions'),
          const SizedBox(width: 10),
          _statCard(_emotionEmoji[_topEmotion] ?? '😊', 'Top Emotion',
            _topEmotion, _emotionColor[_topEmotion] ?? Colors.grey, 'Most expressed'),
          const SizedBox(width: 10),
          _statCard('💚', 'Positive', '${(ratio * 100).round()}%',
            ratio >= 0.5 ? Colors.green : Colors.orange, 'Mood ratio'),
          const SizedBox(width: 10),
          _statCard('📅', 'This Week', '$_weekExpressions', Colors.blue, 'Expressions'),
        ]),
        const SizedBox(height: 14),

        Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Left — emotion frequency + 7-day trend
          Expanded(flex: 5, child: Column(children: [
            Expanded(flex: 3, child: _card('Emotion Frequency (All 8 Emotions)',
              Icons.bar_chart_rounded, _buildFullEmotionBars(total))),
            const SizedBox(height: 12),
            Expanded(flex: 2, child: _card('Emotion Trend',
              Icons.calendar_today_rounded, _buildSevenDayTrend())),
          ])),
          const SizedBox(width: 12),
          // Right — time of day + weekly weeks comparison
          Expanded(flex: 3, child: Column(children: [
            Expanded(flex: 2, child: _card('Time of Day Patterns',
              Icons.access_time_rounded, _buildTimeOfDayWidget())),
            const SizedBox(height: 12),
            Expanded(child: _card('Emotions by Game',
              Icons.gamepad_rounded, _buildEmotionByGame())),
          ])),
        ])),
      ]),
    );
  }

  Widget _buildFullEmotionBars(int total) {
    const ordered = ['Joy', 'Trust', 'Surprise', 'Anticipation', 'Anger', 'Disgust', 'Fear', 'Sadness'];
    if (_emotionFreq.isEmpty) {
      return Center(child: Text('No emotion data yet',
        style: _ts(sz: 14, color: Colors.grey[400]!)));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: ordered.map((emotion) {
        final count = _emotionFreq[emotion] ?? 0;
        final pct = total > 0 ? count / total : 0.0;
        final color = _emotionColor[emotion] ?? Colors.grey;
        final emoji = _emotionEmoji[emotion] ?? '😊';
        final isPos = _positiveSet.contains(emotion);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.5),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 17)),
            const SizedBox(width: 5),
            SizedBox(width: 95, child: Row(children: [
              Flexible(child: Text(emotion, style: _ts(sz: 12, fw: FontWeight.w600))),
              if (isPos) ...[
                const SizedBox(width: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('+', style: _ts(sz: 9, color: Colors.green, fw: FontWeight.w700)),
                ),
              ],
            ])),
            Expanded(child: Stack(children: [
              Container(height: 13, decoration: BoxDecoration(
                color: Colors.grey[100], borderRadius: BorderRadius.circular(6))),
              FractionallySizedBox(
                widthFactor: pct.clamp(0.0, 1.0),
                child: Container(height: 13, decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(6),
                )),
              ),
            ])),
            const SizedBox(width: 6),
            SizedBox(width: 28, child: Text('$count',
              style: _ts(sz: 12, color: Colors.grey[500]!), textAlign: TextAlign.end)),
            SizedBox(width: 36, child: Text('${(pct * 100).round()}%',
              style: _ts(sz: 12, color: color, fw: FontWeight.w700), textAlign: TextAlign.end)),
          ]),
        );
      }).toList(),
    );
  }

  Widget _buildSevenDayTrend() {
    // Tally positive / negative emotion counts across the last 7 days
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final positive = List<double>.filled(7, 0);
    final negative = List<double>.filled(7, 0);
    for (int i = 0; i < 7; i++) {
      final day = days[i];
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final data = _dailyBreakdown[key] ?? {};
      data.forEach((emotion, count) {
        if (_positiveSet.contains(emotion)) {
          positive[i] += count.toDouble();
        } else {
          negative[i] += count.toDouble();
        }
      });
    }

    // Fallback mock data when tracking has no entries yet
    final hasAnyData =
        positive.any((v) => v > 0) || negative.any((v) => v > 0);
    if (!hasAnyData) {
      const pos = [3.0, 5.0, 4.0, 7.0, 6.0, 8.0, 9.0];
      const neg = [6.0, 5.0, 4.0, 3.0, 4.0, 2.0, 1.0];
      for (int i = 0; i < 7; i++) {
        positive[i] = pos[i];
        negative[i] = neg[i];
      }
    }

    const posColor = Color(0xFF22C55E); // green
    const negColor = Color(0xFFEF4444); // red

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Emotions expressed on the week — positive vs negative shifts',
          style: _ts(sz: 11, color: Colors.grey[600]!, fw: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _legendDot(posColor, 'Positive'),
            const SizedBox(width: 14),
            _legendDot(negColor, 'Negative'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
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
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: Colors.grey[200]!, strokeWidth: 1),
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
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('Day ${idx + 1}',
                              style: _ts(sz: 10, fw: FontWeight.w600)),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (value, _) {
                      if (value == 0 ||
                          value == 1 ||
                          value == 5 ||
                          value == 10) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(value.toInt().toString(),
                              style: _ts(sz: 10, fw: FontWeight.w600)),
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
                      _ts(sz: 11, color: Colors.white, fw: FontWeight.w600),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(
                      7, (i) => FlSpot(i.toDouble(), positive[i])),
                  isCurved: true,
                  color: posColor,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 3.5,
                      color: posColor,
                      strokeWidth: 1.5,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: posColor.withValues(alpha: 0.12),
                  ),
                ),
                LineChartBarData(
                  spots: List.generate(
                      7, (i) => FlSpot(i.toDouble(), negative[i])),
                  isCurved: true,
                  color: negColor,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 3.5,
                      color: negColor,
                      strokeWidth: 1.5,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: negColor.withValues(alpha: 0.10),
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
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: _ts(sz: 11, fw: FontWeight.w600)),
      ],
    );
  }

  Widget _buildTimeOfDayWidget() {
    final tod = _timeOfDay;
    final slots = ['Morning 6–12', 'Afternoon 12–18', 'Evening 18–22'];
    final icons = ['🌅', '☀️', '🌙'];
    final colors = [Colors.orange, Colors.amber.shade700, Colors.indigo];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: slots.asMap().entries.map((entry) {
        final i = entry.key;
        final slot = entry.value;
        final data = tod[slot] ?? {};
        final total = data.values.fold(0, (s, v) => s + v);
        final top = data.isEmpty ? null
            : data.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors[i].withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors[i].withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              Text(icons[i], style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(slot.split(' ').first, style: _ts(sz: 13, fw: FontWeight.w700)),
                Text(total > 0 ? '$total expressions' : 'No data yet',
                  style: _ts(sz: 11, color: Colors.grey[500]!)),
              ])),
              if (top != null) ...[
                Text(_emotionEmoji[top] ?? '😊', style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 4),
                Text(top, style: _ts(sz: 12,
                  color: _emotionColor[top] ?? Colors.grey, fw: FontWeight.w600)),
              ],
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmotionByGame() {
    if (_gameFreq.isEmpty) {
      return Center(child: Text('No data yet', style: _ts(sz: 13, color: Colors.grey[400]!)));
    }
    final sorted = _gameFreq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(4).toList();
    final maxVal = top.first.value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: top.map((e) {
        final color = _gameColor[e.key] ?? Colors.blue;
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(children: [
            Text(_gameEmoji[e.key] ?? '🎮', style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 5),
            SizedBox(width: 68, child: Text(e.key, style: _ts(sz: 12, fw: FontWeight.w600),
              overflow: TextOverflow.ellipsis)),
            Expanded(child: Stack(children: [
              Container(height: 8, decoration: BoxDecoration(
                color: Colors.grey[200], borderRadius: BorderRadius.circular(4))),
              FractionallySizedBox(
                widthFactor: maxVal > 0 ? e.value / maxVal : 0,
                child: Container(height: 8, decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(4))),
              ),
            ])),
            const SizedBox(width: 5),
            Text('${e.value}', style: _ts(sz: 11, color: Colors.grey[600]!)),
          ]),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // TAB 2 — GAMES
  // ─────────────────────────────────────────────────────────────────
  Widget _gamesTab() {
    final totalPlays = _gameStats.values.fold(0, (s, g) => s + g.plays);
    final scored = _gameStats.values.where((g) => g.avgScore > 0).toList();
    final avgScore = scored.isEmpty ? 0.0
        : scored.map((g) => g.avgScore).reduce((a, b) => a + b) / scored.length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Game Analytics', style: _ts(sz: 28, fw: FontWeight.w700, color: const Color(0xFF6B21A8))),
        Text("How $_childName engages with each game",
          style: _ts(sz: 15, color: Colors.grey[600]!)),
        const SizedBox(height: 14),

        Row(children: [
          _statCard('🎮', 'Total', '$totalPlays', Colors.blue, 'Sessions'),
          const SizedBox(width: 10),
          _statCard('📊', 'Avg Score', '${avgScore.round()}%', Colors.green, 'Accuracy'),
          const SizedBox(width: 10),
          _statCard(_gameEmoji[_mostPlayedGame] ?? '🏆', 'Most Played',
            _mostPlayedGame, Colors.purple, 'Favourite'),
          const SizedBox(width: 10),
          _statCard(_gameEmoji[_bestScoringGame] ?? '⭐', 'Best Score',
            _bestScoringGame, Colors.orange, 'Highest avg'),
        ]),
        const SizedBox(height: 14),

        Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Left — per-game table
          Expanded(flex: 3, child: _card('Per-Game Performance',
            Icons.table_chart_rounded, _buildGameTable())),
          const SizedBox(width: 12),
          // Right — stars + accuracy bars
          Expanded(flex: 2, child: Column(children: [
            Expanded(flex: 3, child: _card('Stars per Game',
              Icons.star_rounded, _buildGameStarBars())),
            const SizedBox(height: 12),
            Expanded(flex: 2, child: _card('Avg Time per Game',
              Icons.timer_rounded, _buildGameTimeBars())),
          ])),
        ])),
      ]),
    );
  }

  Widget _buildGameTable() {
    if (_gameStats.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🎮', style: TextStyle(fontSize: 44)),
        const SizedBox(height: 10),
        Text('No games played yet', style: _ts(sz: 15, color: Colors.grey[400]!)),
        Text('Complete a game to see stats here', style: _ts(sz: 12, color: Colors.grey[300]!)),
      ]));
    }
    final sorted = _gameStats.entries.toList()
      ..sort((a, b) => b.value.plays.compareTo(a.value.plays));

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Header
      Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF6B21A8).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(children: [
          Expanded(flex: 3, child: Text('Game', style: _ts(sz: 12, fw: FontWeight.w700,
            color: const Color(0xFF6B21A8)))),
          Expanded(child: Text('Plays', style: _ts(sz: 12, fw: FontWeight.w700,
            color: const Color(0xFF6B21A8)))),
          Expanded(child: Text('Stars', style: _ts(sz: 12, fw: FontWeight.w700,
            color: const Color(0xFF6B21A8)))),
          Expanded(child: Text('Score', style: _ts(sz: 12, fw: FontWeight.w700,
            color: const Color(0xFF6B21A8)))),
          Expanded(child: Text('Time', style: _ts(sz: 12, fw: FontWeight.w700,
            color: const Color(0xFF6B21A8)))),
        ]),
      ),
      const SizedBox(height: 6),
      // Rows
      ...sorted.asMap().entries.map((entry) {
        final i = entry.key;
        final e = entry.value;
        final g = e.value;
        final color = _gameColor[e.key] ?? Colors.blue;
        final scoreColor = g.avgScore >= 70 ? Colors.green
            : g.avgScore >= 40 ? Colors.orange : Colors.red;
        final mins = (g.avgSeconds / 60).toStringAsFixed(1);
        return Container(
          margin: const EdgeInsets.only(bottom: 5),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
          decoration: BoxDecoration(
            color: i.isEven ? Colors.grey[50] : Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: Colors.grey[100]!),
          ),
          child: Row(children: [
            Expanded(flex: 3, child: Row(children: [
              Text(_gameEmoji[e.key] ?? '🎮', style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Flexible(child: Text(e.key,
                style: _ts(sz: 13, fw: FontWeight.w700, color: color),
                overflow: TextOverflow.ellipsis)),
            ])),
            Expanded(child: Text('${g.plays}', style: _ts(sz: 13))),
            Expanded(child: Row(children: List.generate(3, (s) => Icon(
              s < g.avgStars.round() ? Icons.star_rounded : Icons.star_outline_rounded,
              color: Colors.orange, size: 13,
            )))),
            Expanded(child: g.avgScore > 0
                ? Text('${g.avgScore.round()}%', style: _ts(sz: 13, color: scoreColor, fw: FontWeight.w700))
                : Text('–', style: _ts(sz: 13, color: Colors.grey[400]!))),
            Expanded(child: Text('${mins}m', style: _ts(sz: 13, color: Colors.grey[600]!))),
          ]),
        );
      }),
    ]);
  }

  Widget _buildGameStarBars() {
    if (_gameStats.isEmpty) {
      return Center(child: Text('No data yet', style: _ts(sz: 13, color: Colors.grey[400]!)));
    }
    final sorted = _gameStats.entries.toList()
      ..sort((a, b) => b.value.avgStars.compareTo(a.value.avgStars));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: sorted.take(6).map((e) {
        final color = _gameColor[e.key] ?? Colors.blue;
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(children: [
            Text(_gameEmoji[e.key] ?? '🎮', style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 5),
            SizedBox(width: 68, child: Text(e.key,
              style: _ts(sz: 12, fw: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            Expanded(child: Stack(children: [
              Container(height: 10, decoration: BoxDecoration(
                color: Colors.grey[200], borderRadius: BorderRadius.circular(5))),
              FractionallySizedBox(
                widthFactor: (e.value.avgStars / 3.0).clamp(0.0, 1.0),
                child: Container(height: 10, decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(5))),
              ),
            ])),
            const SizedBox(width: 5),
            Text('${e.value.avgStars.toStringAsFixed(1)}★',
              style: _ts(sz: 12, color: Colors.orange, fw: FontWeight.w700)),
          ]),
        );
      }).toList(),
    );
  }

  Widget _buildGameTimeBars() {
    if (_gameStats.isEmpty) {
      return Center(child: Text('No data yet', style: _ts(sz: 13, color: Colors.grey[400]!)));
    }
    final sorted = _gameStats.entries.toList()
      ..sort((a, b) => b.value.avgSeconds.compareTo(a.value.avgSeconds));
    final maxSec = sorted.first.value.avgSeconds;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: sorted.take(5).map((e) {
        final color = _gameColor[e.key] ?? Colors.blue;
        final mins = (e.value.avgSeconds / 60).toStringAsFixed(1);
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(children: [
            Text(_gameEmoji[e.key] ?? '🎮', style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            SizedBox(width: 66, child: Text(e.key,
              style: _ts(sz: 11, fw: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            Expanded(child: Stack(children: [
              Container(height: 8, decoration: BoxDecoration(
                color: Colors.grey[200], borderRadius: BorderRadius.circular(4))),
              FractionallySizedBox(
                widthFactor: maxSec > 0 ? (e.value.avgSeconds / maxSec).clamp(0.0, 1.0) : 0,
                child: Container(height: 8, decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(4))),
              ),
            ])),
            const SizedBox(width: 5),
            Text('${mins}m', style: _ts(sz: 11, color: Colors.grey[600]!)),
          ]),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // TAB 3 — REWARDS & GOALS
  // ─────────────────────────────────────────────────────────────────
  Widget _rewardsTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Rewards & Goals', style: _ts(sz: 28, fw: FontWeight.w700,
              color: const Color(0xFF6B21A8))),
            Text("$_childName's achievements and targets",
              style: _ts(sz: 15, color: Colors.grey[600]!)),
          ])),
          ElevatedButton.icon(
            onPressed: () async {
              final saved = await NewGoalDialog.show(context);
              if (saved == true) {
                final goals = await GoalService.getAllGoals();
                if (mounted) {
                  setState(() => _activeGoals = goals.map((g) => <String, dynamic>{
                    'id': g.id,
                    'label': '${g.category.label} — ${g.target} ${g.duration.label}',
                    'progress': g.progressFraction,
                    'current': g.currentProgress,
                    'target': g.target,
                    'emoji': g.category.emoji,
                  }).toList());
                }
              }
            },
            icon: const Icon(Icons.add_circle_outline, size: 20),
            label: Text('New Goal', style: _ts(sz: 15, color: Colors.white, fw: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B21A8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
        const SizedBox(height: 14),

        Row(children: [
          _statCard('⭐', 'Total Stars', '$_totalStars', Colors.orange, 'Earned'),
          const SizedBox(width: 10),
          _statCard('🏅', 'Rewards', '$_rewardsUnlocked', Colors.green, 'Unlocked'),
          const SizedBox(width: 10),
          _statCard('🎯', 'Goals', '${_activeGoals.length}', Colors.blue, 'Active'),
          const SizedBox(width: 10),
          _statCard('🎮', 'Games', '$_totalActivities', Colors.purple, 'Completed'),
        ]),
        const SizedBox(height: 14),

        Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Goals
          Expanded(child: _card('Active Goals', Icons.flag_rounded, _buildGoalsList())),
          const SizedBox(width: 14),
          // Rewards
          Expanded(child: _card('Earned Rewards', Icons.emoji_events_rounded,
            FutureBuilder<List<ChildReward>>(
              future: ChildRewardsService.getAllRewards(),
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final unlocked = snap.data!.where((r) => r.isUnlocked).toList();
                final locked = snap.data!.where((r) => !r.isUnlocked).take(5).toList();
                if (unlocked.isEmpty && locked.isEmpty) {
                  return Center(child: Text('Play to earn rewards!',
                    style: _ts(sz: 14, color: Colors.grey[400]!)));
                }
                return SingleChildScrollView(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (unlocked.isNotEmpty) ...[
                      Text('Unlocked (${unlocked.length})',
                        style: _ts(sz: 13, fw: FontWeight.w700, color: Colors.green)),
                      const SizedBox(height: 6),
                      ...unlocked.map((r) => _rewardTile(
                        r.emoji, r.title, r.description, true, r.unlockedAt)),
                    ],
                    if (locked.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('Up Next', style: _ts(sz: 13, fw: FontWeight.w700,
                        color: Colors.grey[500]!)),
                      const SizedBox(height: 6),
                      ...locked.take(4).map((r) => _rewardTile(
                        r.emoji, r.title,
                        '${r.milestoneStars ?? r.starCost}⭐ needed', false, null)),
                    ],
                  ],
                ));
              },
            ),
          )),
        ])),
      ]),
    );
  }

  Widget _buildGoalsList() {
    if (_activeGoals.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🎯', style: TextStyle(fontSize: 38)),
        const SizedBox(height: 8),
        Text('No goals yet', style: _ts(sz: 14, color: Colors.grey[400]!)),
        Text('Tap "New Goal" to set a target',
          style: _ts(sz: 12, color: Colors.grey[300]!)),
      ]));
    }
    return SingleChildScrollView(child: Column(
      mainAxisSize: MainAxisSize.min,
      children: _activeGoals.asMap().entries.map((entry) {
        final i = entry.key;
        final g = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFF6B21A8).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6B21A8).withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            Text(g['emoji'] as String, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Flexible(child: Text(g['label'] as String,
                  style: _ts(sz: 14, fw: FontWeight.w600))),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${g['current']}/${g['target']}',
                    style: _ts(sz: 14, color: const Color(0xFF6B21A8), fw: FontWeight.w700)),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Text('Remove Goal?', style: _ts(sz: 18, fw: FontWeight.w700)),
                          content: Text('Are you sure?',
                            style: _ts(sz: 14, color: Colors.grey[700]!)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false),
                              child: Text('Cancel', style: _ts(sz: 14, color: Colors.grey))),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
                              child: Text('Remove', style: _ts(sz: 14, color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        final id = g['id'] as String?;
                        if (id != null) await GoalService.deleteGoal(id);
                        if (mounted) setState(() => _activeGoals.removeAt(i));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.close, color: Colors.red, size: 15),
                    ),
                  ),
                ]),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (g['progress'] as double).clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: const Color(0xFF6B21A8).withValues(alpha: 0.12),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF6B21A8)),
                ),
              ),
            ])),
          ]),
        );
      }).toList(),
    ));
  }

  Widget _rewardTile(String emoji, String title, String sub, bool earned, DateTime? when) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: earned ? const Color(0xFFFFF3E0) : Colors.grey[50],
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: earned ? Colors.orange.shade200 : Colors.grey.shade200),
      ),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 26)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: _ts(sz: 14, fw: FontWeight.w700)),
          Text(when != null ? 'Earned ${_timeAgo(when)}' : sub,
            style: _ts(sz: 12, color: earned ? Colors.green : Colors.grey[500]!)),
        ])),
        if (earned) const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // TAB 4 — SETTINGS
  // ─────────────────────────────────────────────────────────────────
  Widget _settingsTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Settings', style: _ts(sz: 28, fw: FontWeight.w700, color: const Color(0xFF6B21A8))),
        Text('Manage your account, security and preferences',
          style: _ts(sz: 15, color: Colors.grey[600]!)),
        const SizedBox(height: 20),
        Expanded(child: Column(children: [
          Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _card('Account', Icons.person_outline_rounded, Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _settingsRow(Icons.edit, 'Edit Profile', 'Update your centre name',
                  onTap: _showEditProfileDialog),
                const Divider(height: 1),
                _settingsRow(Icons.lock_outline, 'Change Password', 'Update your login password',
                  onTap: _showChangePasswordDialog),
                const Divider(height: 1),
                _settingsRow(Icons.link, 'Share Code', 'Generate a code to link accounts',
                  onTap: _showShareCodeDialog),
              ],
            ))),
            const SizedBox(width: 14),
            Expanded(child: _card('Notifications', Icons.notifications_outlined, Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _toggleRow(Icons.emoji_events_outlined, 'Reward Alerts',
                  'When child earns a reward', _rewardAlerts,
                  (v) => setState(() => _rewardAlerts = v)),
                const Divider(height: 1),
                _toggleRow(Icons.calendar_today, 'Session Reminders',
                  'Upcoming sessions', _sessionReminders,
                  (v) => setState(() => _sessionReminders = v)),
              ],
            ))),
          ])),
          const SizedBox(height: 14),
          Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _card('Security', Icons.shield_outlined, Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _settingsRow(Icons.pin, 'Parent Gate PIN',
                  'Set or change your 4-digit PIN', onTap: _showParentPinDialog),
              ],
            ))),
            const SizedBox(width: 14),
            Expanded(child: _card('Account Management', Icons.manage_accounts_rounded, Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _settingsRow(Icons.logout, 'Log Out', 'Sign out of your account',
                  onTap: _showLogoutDialog),
                const Divider(height: 1),
                _settingsRow(Icons.delete_forever, 'Deactivate Account',
                  'Permanently deactivate', iconColor: Colors.red,
                  onTap: _showDeactivateDialog),
              ],
            ))),
          ])),
        ])),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // SHARED WIDGETS
  // ─────────────────────────────────────────────────────────────────
  Widget _statCard(String emoji, String title, String value, Color color, String sub) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: color.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(11)),
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: _ts(sz: 20, fw: FontWeight.w700),
              overflow: TextOverflow.ellipsis, maxLines: 1),
            Text(title, style: _ts(sz: 12, color: Colors.grey[600]!), maxLines: 2),
            Text(sub, style: _ts(sz: 11, color: color, fw: FontWeight.w500)),
          ])),
        ]),
      ),
    );
  }

  Widget _card(String title, IconData icon, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: Colors.grey.withValues(alpha: 0.09), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(icon, color: const Color(0xFF6B21A8), size: 20),
            const SizedBox(width: 7),
            Flexible(child: Text(title, style: _ts(sz: 17, fw: FontWeight.w700))),
          ]),
          const SizedBox(height: 10),
          Flexible(child: child),
        ]),
    );
  }

  Widget _settingsRow(IconData icon, String title, String sub,
      {VoidCallback? onTap, Color? iconColor}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        child: Row(children: [
          Icon(icon, color: iconColor ?? const Color(0xFF6B21A8), size: 22),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: _ts(sz: 15, fw: FontWeight.w600)),
            Text(sub, style: _ts(sz: 12, color: Colors.grey[500]!, fw: FontWeight.w400)),
          ])),
          Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
        ]),
      ),
    );
  }

  Widget _toggleRow(IconData icon, String title, String sub, bool val,
      ValueChanged<bool> onChange) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF6B21A8), size: 22),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: _ts(sz: 15, fw: FontWeight.w600)),
          Text(sub, style: _ts(sz: 12, color: Colors.grey[500]!, fw: FontWeight.w400)),
        ])),
        Switch(value: val, onChanged: onChange, activeColor: const Color(0xFF6B21A8)),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // SETTINGS DIALOGS
  // ─────────────────────────────────────────────────────────────────
  void _showEditProfileDialog() {
    final ctrl = TextEditingController(text: _centreName);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('Edit Profile', style: _ts(sz: 20, fw: FontWeight.w700)),
      content: SizedBox(width: 340, child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: 'Centre Name',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
        ),
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel', style: _ts(sz: 14, color: Colors.grey))),
        ElevatedButton(
          onPressed: () {
            setState(() => _centreName = ctrl.text);
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Profile updated!')));
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B21A8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: Text('Save', style: _ts(sz: 14, color: Colors.white, fw: FontWeight.w600)),
        ),
      ],
    ));
  }

  void _showChangePasswordDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('Change Password', style: _ts(sz: 20, fw: FontWeight.w700)),
      content: SizedBox(width: 340, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(obscureText: true, decoration: InputDecoration(
          labelText: 'New Password',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
        )),
        const SizedBox(height: 10),
        TextField(obscureText: true, decoration: InputDecoration(
          labelText: 'Confirm Password',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
        )),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel', style: _ts(sz: 14, color: Colors.grey))),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Password updated!')));
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B21A8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: Text('Save', style: _ts(sz: 14, color: Colors.white, fw: FontWeight.w600)),
        ),
      ],
    ));
  }

  void _showShareCodeDialog() {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final code = uid.length >= 8 ? uid.substring(0, 8).toUpperCase() : 'N/A';
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('Share Code', style: _ts(sz: 20, fw: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF6B21A8).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(code, style: _ts(sz: 30, fw: FontWeight.w700,
            color: const Color(0xFF6B21A8))),
        ),
        const SizedBox(height: 10),
        Text('Share this code to link accounts',
          style: _ts(sz: 13, color: Colors.grey[600]!)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
          child: Text('Close', style: _ts(sz: 14, color: Colors.grey))),
      ],
    ));
  }

  void _showParentPinDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('Parent Gate PIN', style: _ts(sz: 20, fw: FontWeight.w700)),
      content: SizedBox(width: 340, child: TextField(
        keyboardType: TextInputType.number,
        maxLength: 4,
        obscureText: true,
        decoration: InputDecoration(
          labelText: 'New 4-digit PIN',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
        ),
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel', style: _ts(sz: 14, color: Colors.grey))),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('PIN updated!')));
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B21A8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: Text('Save', style: _ts(sz: 14, color: Colors.white, fw: FontWeight.w600)),
        ),
      ],
    ));
  }

  void _showLogoutDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('Log Out', style: _ts(sz: 20, fw: FontWeight.w700)),
      content: Text('Are you sure you want to log out?',
        style: _ts(sz: 14, color: Colors.grey[700]!)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel', style: _ts(sz: 14, color: Colors.grey))),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await Supabase.instance.client.auth.signOut();
            if (mounted) context.go('/login');
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: Text('Log Out', style: _ts(sz: 14, color: Colors.white, fw: FontWeight.w600)),
        ),
      ],
    ));
  }

  void _showDeactivateDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('Deactivate Account',
        style: _ts(sz: 20, fw: FontWeight.w700, color: Colors.red)),
      content: Text(
        'This will permanently deactivate your account and cannot be undone.',
        style: _ts(sz: 14, color: Colors.grey[700]!)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel', style: _ts(sz: 14, color: Colors.grey))),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: Text('Deactivate', style: _ts(sz: 14, color: Colors.white, fw: FontWeight.w600)),
        ),
      ],
    ));
  }
}
