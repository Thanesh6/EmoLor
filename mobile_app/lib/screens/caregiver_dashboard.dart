import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/emotion_colour_mapping.dart';
import '../core/services/emotion_journal_service.dart';
import '../core/services/star_service.dart';
import '../features/caregiver/presentation/screens/progress_dashboard_screen.dart';
import '../features/caregiver/presentation/widgets/new_goal_dialog.dart';
import '../features/caregiver/services/goal_service.dart';
import '../features/child/services/child_rewards_service.dart';
import '../features/child/services/completion_service.dart';
import '../features/child/models/completion_record.dart';

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
  int _selectedNavIndex = 0;
  String _caregiverName = 'Caregiver';
  String _caregiverAvatar = '😊';
  late String _childName;
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
      final stars = await StarService.getTotalStars();
      final rewards = await ChildRewardsService.getUnlockedCount();
      final completions = await CompletionService.history();
      final emotionFreq = await EmotionJournalService.getEmotionFrequency();
      final gameFreq = await EmotionJournalService.getGameFrequency();
      final journal = await EmotionJournalService.getEntries();

      // Calculate today's activities
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayCompletions = completions.where(
          (c) => c.completedAt.isAfter(todayStart)).toList();

      // This week's expressions (journal entries)
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
      final weekExpressions = journal.where((e) {
        final ts = DateTime.parse(e['timestamp'] as String);
        return ts.isAfter(weekStartDate);
      }).length;

      // Load user-created goals (must be outside setState — it's async)
      final serviceGoals = await GoalService.getAllGoals();

      if (mounted) {
        setState(() {
          _totalStars = stars;
          _rewardsUnlocked = rewards;
          _totalActivities = completions.length;
          _todayActivities = todayCompletions.length;
          _weekExpressions = weekExpressions;
          _emotionFreq = emotionFreq;
          _gameFreq = gameFreq;
          _recentCompletions = completions.take(4).toList();
          _recentJournal = journal.reversed.take(10).toList();
          _activeGoals = serviceGoals.map((g) => <String, dynamic>{
            'id': g.id,
            'label': '${g.category.label} — ${g.target} ${g.duration.label}',
            'current': 0,
            'target': g.target,
            'color': 'purple',
            'emoji': g.category.emoji,
          }).toList();
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
    // If child name was passed in (org account), skip DB lookup
    if (widget.childName != null && widget.childName!.isNotEmpty) return;
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      // Try to load linked child profile
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
      // Fallback for personal accounts: use the user's own name
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
          final av = profile['avatar_url'] as String?;
          if (av != null && av.isNotEmpty) _caregiverAvatar = av;
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

  // NEW: Fetch recent activities
  Future<List<Map<String, dynamic>>> _fetchRecentActivities() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return [];

      final response = await Supabase.instance.client
          .from('activity_sessions')
          .select()
          .eq('child_id', user.id)
          .order('session_start', ascending: false)
          .limit(5);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching activities: $e');
      return [];
    }
  }

  // Helper to format Duration
  String _timeAgo(String timestamp) {
    // Simple mock time ago logic for now if package not available, relying on DateTime
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
              // Left Sidebar
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
                    // Logo — glowing EMOLOR title
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
                                  color: Colors.white.withValues(alpha: 0.6 + _glowCtrl.value * 0.4),
                                  blurRadius: glow,
                                ),
                                Shadow(
                                  color: const Color(0xFFD8B4FE).withValues(alpha: 0.5),
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
                        'CAREGIVER PORTAL',
                        style: _textStyle(
                            fontSize: 13,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Nav Items — equal spacing
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNavItem(
                              Icons.home_rounded, 'Home', _selectedNavIndex == 0,
                              () {
                            _loadRealData(); // refresh real data on tab switch
                            setState(() => _selectedNavIndex = 0);
                          }),
                          _buildNavItem(
                              Icons.bar_chart_rounded, 'Progress',
                              _selectedNavIndex == 1, () {
                            setState(() => _selectedNavIndex = 1);
                          }),
                          _buildNavItem(
                              Icons.emoji_events_rounded, 'Goals & Rewards',
                              _selectedNavIndex == 2, () {
                            setState(() => _selectedNavIndex = 2);
                          }),
                          _buildNavItem(
                              Icons.chat_bubble_rounded, 'Messages',
                              _selectedNavIndex == 3, () {
                            setState(() => _selectedNavIndex = 3);
                          }),
                          _buildNavItem(
                              Icons.child_care_rounded, 'My Child',
                              _selectedNavIndex == 4, () {
                            setState(() => _selectedNavIndex = 4);
                          }),
                          _buildNavItem(
                              Icons.settings_rounded, 'Settings',
                              _selectedNavIndex == 5, () {
                            setState(() => _selectedNavIndex = 5);
                          }),
                        ],
                      ),
                    ),

                    // Back to Child Dashboard button at bottom
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade300.withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
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

              // Main Content
              Expanded(
                child: _selectedNavIndex == 1
                    ? const ProgressDashboardScreen()
                    : _selectedNavIndex == 2
                        ? _buildGoalsRewardsTab()
                        : _selectedNavIndex == 3
                            ? _buildMessagesTab()
                            : _selectedNavIndex == 4
                                ? _buildMyChildTab()
                                : _selectedNavIndex == 5
                                    ? _buildSettingsTab()
                                    : _buildHomeTab(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Messages Tab (coming soon) ──────────────────────────────────────

  Widget _buildMessagesTab() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coming soon banner at top
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF6B21A8).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.construction_rounded, color: Color(0xFF6B21A8), size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Coming Soon!',
                          style: _textStyle(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF6B21A8))),
                      Text('Messaging and chat features are under development.',
                          style: _textStyle(fontSize: 15, color: Colors.grey[600]!, fontWeight: FontWeight.w400)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Messages',
              style: _textStyle(fontSize: 34, fontWeight: FontWeight.w700, color: const Color(0xFF6B21A8))),
          const SizedBox(height: 4),
          Text('Chat with your child\'s therapist',
              style: _textStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600]!)),
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('💬', style: TextStyle(fontSize: 72)),
                  SizedBox(height: 16),
                  Text('Messaging coming soon', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF6B21A8))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Home Tab (non-scrollable) ──────────────────────────────────────

  Widget _buildHomeTab() {
    return Padding(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome Back! 👋',
                      style: _textStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6B21A8))),
                  Text("Here's an overview of your child's progress",
                      style: _textStyle(fontSize: 18, color: Colors.grey[600]!)),
                ],
              ),
              Row(
                children: [
                  GestureDetector(
                    onTapDown: (details) {
                      final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
                      showMenu(
                        context: context,
                        position: RelativeRect.fromRect(
                          details.globalPosition & const Size(40, 40),
                          Offset.zero & overlay.size,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        color: Colors.white,
                        items: <PopupMenuEntry>[
                          PopupMenuItem(
                            enabled: false,
                            child: Text('Notifications',
                                style: _textStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF6B21A8))),
                          ),
                          const PopupMenuDivider(),
                          ...(_recentCompletions.isEmpty
                            ? [
                                PopupMenuItem(
                                  enabled: false,
                                  child: Text('No recent activity',
                                      style: _textStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                ),
                              ]
                            : _recentCompletions.take(3).map((c) =>
                                PopupMenuItem(
                                  enabled: false,
                                  child: Text(
                                    '🎮 ${_childName} completed ${c.activityName} — ${_timeAgo(c.completedAt.toIso8601String())}',
                                    style: _textStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ).toList()),
                          PopupMenuItem(
                            enabled: false,
                            child: Text(
                              '⭐ $_totalStars total stars earned',
                              style: _textStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      );
                    },
                    child: _buildHeaderButton(Icons.notifications_outlined,
                        '${_recentCompletions.length > 0 ? _recentCompletions.length : 0}'),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedNavIndex = 3);
                    },
                    child: _buildHeaderButton(Icons.message_outlined, '0'),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Stats Cards — real data
          Row(
            children: [
              _buildStatCard('🎮', 'Activities', '$_todayActivities', Colors.blue, 'Today'),
              const SizedBox(width: 10),
              _buildStatCard('⭐', 'Stars', '$_totalStars', Colors.orange, 'Total'),
              const SizedBox(width: 10),
              _buildStatCard('🏅', 'Rewards', '$_rewardsUnlocked', Colors.green, 'Earned'),
              const SizedBox(width: 10),
              _buildStatCard('🗣️', 'Express', '$_weekExpressions', Colors.purple, 'This week'),
            ],
          ),

          const SizedBox(height: 14),

          // Main Content — fills remaining space
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: Recent Activity + Emotion Trends
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Expanded(
                        child: _buildCard(
                          'Recent Activity',
                          Icons.history,
                          Builder(
                            builder: (context) {
                              final gameEmojis = {
                                'EMOZZLE': '🧩', 'EMOPOP': '🫧', 'EMOSPELL': '🔤',
                                'EMOSORT': '📋', 'EMOSLASH': '⚔️', 'EMOCATCH': '🎯',
                                'Draw': '🖌️', 'Express Cards': '🗣️', 'My Colours': '🎨',
                              };
                              final gameColors = {
                                'EMOZZLE': Colors.purple, 'EMOPOP': Colors.blue,
                                'EMOSPELL': Colors.green, 'EMOSORT': Colors.orange,
                                'EMOSLASH': Colors.red, 'EMOCATCH': Colors.teal,
                                'Draw': Colors.pink, 'Express Cards': Colors.indigo, 'My Colours': Colors.amber,
                              };
                              if (_recentCompletions.isNotEmpty) {
                                final items = _recentCompletions.map((c) {
                                  final name = c.activityName;
                                  final emoji = gameEmojis[name] ?? '🎮';
                                  final color = gameColors[name] ?? Colors.blue;
                                  return _buildActivityItem(
                                      emoji,
                                      '$name (⭐${c.starsEarned})',
                                      _timeAgo(c.completedAt.toIso8601String()),
                                      color);
                                }).toList();
                                return _buildActivityGrid(items);
                              }
                              // Sample entries when no real data yet
                              return _buildActivityGrid([
                                _buildActivityItem('🧩', 'EMOZZLE (⭐3)', '5 mins ago', Colors.purple),
                                _buildActivityItem('🫧', 'EMOPOP (⭐2)', '20 mins ago', Colors.blue),
                                _buildActivityItem('🔤', 'EMOSPELL (⭐4)', '1 hour ago', Colors.green),
                                _buildActivityItem('📋', 'EMOSORT (⭐1)', '2 hours ago', Colors.orange),
                              ]);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _buildCard(
                          'Emotion Trends',
                          Icons.insights,
                          Builder(
                            builder: (context) {
                              final emotionColors = {
                                'Happy': Colors.green, 'Sad': Colors.blue,
                                'Angry': Colors.red, 'Scared': Colors.purple,
                                'Excited': Colors.orange, 'Calm': Colors.teal,
                                'Surprised': Colors.amber, 'Disgusted': Colors.brown,
                              };
                              if (_emotionFreq.isNotEmpty) {
                                final sorted = _emotionFreq.entries.toList()
                                  ..sort((a, b) => b.value.compareTo(a.value));
                                final top = sorted.take(4).toList();
                                final maxVal = top.first.value.toDouble();
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: top.map((e) => _buildEmotionBar(
                                      e.key,
                                      maxVal > 0 ? e.value / maxVal : 0,
                                      emotionColors[e.key] ?? Colors.grey,
                                  )).toList(),
                                );
                              }
                              // Sample emotion trends
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildEmotionBar('Happy', 0.85, Colors.green),
                                  _buildEmotionBar('Calm', 0.65, Colors.teal),
                                  _buildEmotionBar('Excited', 0.50, Colors.orange),
                                  _buildEmotionBar('Sad', 0.20, Colors.blue),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Right: Child Profile + Quick Actions
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      // Child profile — avatar+name left, stats right
                      _buildCard(
                        'Child Profile',
                        Icons.person,
                        Row(
                          children: [
                            // Left: avatar + name
                            Container(
                              width: 55,
                              height: 55,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: [Color(0xFFFFB74D), Color(0xFFFF8A65)]),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                              child: Center(
                                  child: Text(_childAvatar,
                                      style: const TextStyle(fontSize: 30))),
                            ),
                            const SizedBox(width: 14),
                            Text(_childName,
                                style: _textStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700)),
                            const Spacer(),
                            // Right: real stats vertically
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('⭐ $_totalStars Stars',
                                    style: _textStyle(
                                        fontSize: 15,
                                        color: Colors.orange[700]!,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text('🏅 $_rewardsUnlocked Rewards',
                                    style: _textStyle(
                                        fontSize: 15,
                                        color: Colors.blue[700]!,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text('🎮 $_totalActivities Games',
                                    style: _textStyle(
                                        fontSize: 15,
                                        color: Colors.green[700]!,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Quick Actions — fills remaining
                      Expanded(
                        child: _buildCard(
                          'Quick Actions',
                          Icons.flash_on,
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildQuickAction(
                                  '📊', 'View Full Report', Colors.blue),
                              _buildQuickAction(
                                  '📝', 'Add Note', Colors.green),
                              _buildQuickAction(
                                  '🎯', 'Set Goal', Colors.orange),
                              _buildQuickAction(
                                  '📞', 'Contact Therapist', Colors.purple),
                              _buildQuickAction(
                                  '📅',
                                  'Request Session',
                                  const Color(0xFF6B21A8),
                                  onTap: () => context.push('/request-session')),
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
                style: _textStyle(
                    fontSize: 28, fontWeight: FontWeight.w700)),
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
                          fontSize: 15, color: color, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, IconData icon, Widget child) {
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
              Text(
                title,
                style: _textStyle(fontSize: 26, fontWeight: FontWeight.w700),
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
              Text(emotion, style: _textStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              Text('${(value * 100).toInt()}%',
                  style: _textStyle(fontSize: 18, color: color, fontWeight: FontWeight.w700)),
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

  // ── My Child's Colours Card ────────────────────────────────────────

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Goals & Rewards',
                        style: _textStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF6B21A8))),
                    const SizedBox(height: 4),
                    Text("Set targets and track your child's reward progress",
                        style: _textStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600]!)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final saved = await NewGoalDialog.show(context);
                  if (saved == true) {
                    final serviceGoals = await GoalService.getAllGoals();
                    if (mounted) {
                      setState(() {
                        _activeGoals = serviceGoals.map((g) => <String, dynamic>{
                          'label': '${g.category.label} — ${g.target} ${g.duration.label}',
                          'current': 0,
                          'target': g.target,
                          'color': 'purple',
                          'emoji': g.category.emoji,
                        }).toList();
                      });
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
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
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
                          return Center(
                            child: Text('No active goals — create one!',
                                style: _textStyle(fontSize: 16, color: Colors.grey[400]!)),
                          );
                        }
                        final colorMap = {
                          'orange': Colors.orange, 'blue': Colors.blue,
                          'green': Colors.green, 'purple': Colors.purple,
                          'red': Colors.red, 'teal': Colors.teal,
                        };
                        return Column(
                          children: _activeGoals.asMap().entries.map((entry) {
                            final i = entry.key;
                            final g = entry.value;
                            final current = (g['current'] as int?) ?? 0;
                            final target = (g['target'] as int?) ?? 1;
                            final progress = target > 0 ? current / target : 0.0;
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
                      future: ChildRewardsService.getAllRewards(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final allRewards = snapshot.data!;
                        final unlocked = allRewards.where((r) => r.unlockedAt != null).toList();
                        final locked = allRewards.where((r) => r.unlockedAt == null).take(4 - unlocked.length.clamp(0, 4)).toList();
                        final display = [...unlocked.take(4), ...locked].take(4).toList();

                        if (display.isEmpty) {
                          return Center(child: Text('No rewards yet', style: _textStyle(fontSize: 16, color: Colors.grey[400]!)));
                        }

                        final rows = <Widget>[];
                        for (int i = 0; i < display.length; i += 2) {
                          rows.add(Row(
                            children: [
                              Expanded(child: _buildRewardChip(
                                display[i].emoji, display[i].title, display[i].unlockedAt != null)),
                              const SizedBox(width: 14),
                              if (i + 1 < display.length)
                                Expanded(child: _buildRewardChip(
                                  display[i + 1].emoji, display[i + 1].title, display[i + 1].unlockedAt != null))
                              else
                                const Expanded(child: SizedBox()),
                            ],
                          ));
                          if (i + 2 < display.length) rows.add(const SizedBox(height: 14));
                        }
                        return Column(children: rows);
                      },
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

  Widget _buildGoalRow(
      String label, double progress, String progressText, Color color, String emoji,
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
                          style: _textStyle(fontSize: 20, fontWeight: FontWeight.w600)),
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
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: Text('Remove Goal?', style: _textStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                                  content: Text('Are you sure you want to remove this goal?',
                                      style: _textStyle(fontSize: 16, color: Colors.grey[700]!)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: Text('Cancel', style: _textStyle(fontSize: 16, color: Colors.grey)),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: Text('Remove', style: _textStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
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
                              child: const Icon(Icons.close, color: Colors.red, size: 18),
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
                    style: _textStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

  // ── My Child Tab ─────────────────────────────────────────────────

  Widget _buildMyChildTab() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My Child',
              style: _textStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6B21A8))),
          const SizedBox(height: 4),
          Text("View your child's profile, colours and emotion journey",
              style: _textStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600]!)),
          const SizedBox(height: 16),

          // Main content — 2x2 grid filling remaining space
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // LEFT column — Profile + Interaction Log
                SizedBox(
                  width: 300,
                  child: Column(
                    children: [
                      // Child Profile card
                      Expanded(
                        flex: 3,
                        child: _buildMyChildCard(
                          'Child Profile',
                          Icons.person,
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                      colors: [Color(0xFFFFB74D), Color(0xFFFF8A65)]),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.orange.withValues(alpha: 0.3),
                                        blurRadius: 12),
                                  ],
                                ),
                                child: Center(
                                    child: Text(_childAvatar,
                                        style: const TextStyle(fontSize: 38))),
                              ),
                              const SizedBox(height: 10),
                              Text(_childName.isEmpty ? 'Thanesh' : _childName,
                                  style: _textStyle(
                                      fontSize: 22, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text('Emoji Explorer',
                                  style: _textStyle(
                                      fontSize: 14, color: Colors.grey[500]!)),
                              const SizedBox(height: 12),
                              _buildChildDetailRow('🎂', 'Age', '7 years old'),
                              const SizedBox(height: 6),
                              _buildChildDetailRow('🧩', 'Level', 'Beginner'),
                              const SizedBox(height: 6),
                              _buildChildDetailRow('📅', 'Joined', 'Mar 2026'),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Emotion Interaction Log
                      Expanded(
                        flex: 2,
                        child: _buildMyChildCard(
                          'Interaction Log',
                          Icons.auto_stories_rounded,
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Recent emotions explored",
                                style: _textStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500]!,
                                    fontWeight: FontWeight.w400),
                              ),
                              const SizedBox(height: 8),
                              Flexible(
                                child: SingleChildScrollView(
                                  child: Builder(
                                    builder: (context) {
                                      if (_recentJournal.isEmpty) {
                                        return Text('No interactions yet',
                                            style: _textStyle(fontSize: 14, color: Colors.grey[400]!));
                                      }
                                      // Deduplicate by emotion name, show most recent per emotion
                                      final seen = <String>{};
                                      final unique = <Map<String, dynamic>>[];
                                      for (final e in _recentJournal) {
                                        final emotion = e['emotion'] as String? ?? '';
                                        if (!seen.contains(emotion)) {
                                          seen.add(emotion);
                                          unique.add(e);
                                        }
                                      }
                                      return Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: unique.take(6).map((e) =>
                                          _buildJournalChip(
                                            e['emoji'] as String? ?? '😊',
                                            e['emotion'] as String? ?? 'Unknown',
                                            e['game'] as String? ?? '',
                                          ),
                                        ).toList(),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 14),

                // RIGHT column — Colours + Learning Preferences
                Expanded(
                  child: Column(
                    children: [
                      // My Child's Colours — 2-column grid
                      Expanded(
                        flex: 3,
                        child: FutureBuilder<void>(
                          future: EmotionColourMapping.ensureLoaded(),
                          builder: (context, snapshot) {
                            return _buildMyChildCard(
                              "My Child's Colours",
                              Icons.palette,
                              Expanded(
                                child: GridView.count(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: 1.0,
                                  children: _emotionList.map((e) {
                                    final color =
                                        EmotionColourMapping.colorFor(e['name']!);
                                    final isDark = color.computeLuminance() < 0.4;
                                    final textColor = isDark ? Colors.white : Colors.black87;
                                    return Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: color.withValues(alpha: 0.45),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(e['emoji']!,
                                              style: const TextStyle(fontSize: 36)),
                                          const SizedBox(height: 6),
                                          Text(
                                            e['name']!,
                                            style: GoogleFonts.fredoka(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: textColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Learning Preferences — 2x2 grid
                      Expanded(
                        flex: 2,
                        child: _buildMyChildCard(
                          'Learning Preferences',
                          Icons.psychology_rounded,
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "How your child learns best",
                                style: _textStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500]!,
                                    fontWeight: FontWeight.w400),
                              ),
                              const SizedBox(height: 10),
                              Builder(
                                builder: (context) {
                                  // Find favourite game from real data
                                  String favGame = 'None yet';
                                  if (_gameFreq.isNotEmpty) {
                                    final sorted = _gameFreq.entries.toList()
                                      ..sort((a, b) => b.value.compareTo(a.value));
                                    favGame = sorted.first.key;
                                  }
                                  // Find top emotion
                                  String topEmotion = 'None yet';
                                  if (_emotionFreq.isNotEmpty) {
                                    final sorted = _emotionFreq.entries.toList()
                                      ..sort((a, b) => b.value.compareTo(a.value));
                                    topEmotion = sorted.first.key;
                                  }
                                  return Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildPreferenceRow(
                                                Icons.speed_rounded, 'Difficulty',
                                                'Adaptive', Colors.blue),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: _buildPreferenceRow(
                                                Icons.games_rounded, 'Favourite Game',
                                                favGame, Colors.purple),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildPreferenceRow(
                                                Icons.emoji_emotions_rounded,
                                                'Top Emotion', topEmotion, Colors.orange),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: _buildPreferenceRow(
                                                Icons.timer_rounded, 'Total Games',
                                                '$_totalActivities', Colors.green),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
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

  // Card specifically for My Child tab — uses Expanded instead of ScrollView
  Widget _buildMyChildCard(String title, IconData icon, Widget child) {
    return Container(
      padding: const EdgeInsets.all(18),
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
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF6B21A8), size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: _textStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildPreferenceRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: _textStyle(
                      fontSize: 15, color: Colors.grey[500]!, fontWeight: FontWeight.w500)),
              Text(value,
                  style: _textStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChildDetailRow(String emoji, String label, String value) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Text('$label: ',
            style: _textStyle(
                fontSize: 16, color: Colors.grey[500]!, fontWeight: FontWeight.w500)),
        Flexible(
          child: Text(value,
              style: _textStyle(fontSize: 16, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
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
          Text('Settings',
              style: _textStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6B21A8))),
          const SizedBox(height: 4),
          Text('Manage your account, security and preferences',
              style: _textStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600]!)),
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
                              _buildSettingsRow(Icons.lock_outline, 'Change Password',
                                  'Update your login password',
                                  onTap: () => _showChangePasswordDialog()),
                              const Divider(height: 1),
                              _buildSettingsRow(Icons.link, 'Share Code',
                                  'Generate a code to link with therapist',
                                  onTap: () => _showShareCodeDialog()),
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
                              _buildToggleRow(Icons.message_outlined, 'Message Alerts',
                                  'New therapist messages', _messageAlerts, (v) {
                                setState(() => _messageAlerts = v);
                              }),
                              const Divider(height: 1),
                              _buildToggleRow(Icons.emoji_events_outlined, 'Reward Alerts',
                                  'When child earns a reward', _rewardAlerts, (v) {
                                setState(() => _rewardAlerts = v);
                              }),
                              const Divider(height: 1),
                              _buildToggleRow(Icons.calendar_today, 'Session Reminders',
                                  'Upcoming therapy sessions', _sessionReminders, (v) {
                                setState(() => _sessionReminders = v);
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
                              _buildSettingsRow(Icons.fingerprint, 'Biometric Lock',
                                  'Use fingerprint to access caregiver settings',
                                  onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Biometric lock coming soon!')),
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
                              _buildSettingsRow(Icons.delete_forever, 'Deactivate Account',
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
                      style: _textStyle(fontSize: 19, fontWeight: FontWeight.w600)),
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

  Widget _buildToggleRow(IconData icon, String title, String subtitle, bool value,
      ValueChanged<bool> onChanged) {
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
                    style: _textStyle(fontSize: 19, fontWeight: FontWeight.w600)),
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
            activeColor: const Color(0xFF6B21A8),
          ),
        ],
      ),
    );
  }

  // ── Settings Dialogs ──────────────────────────────────────────────

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _childName.isEmpty ? 'Thanesh' : _childName);
    final ageCtrl = TextEditingController(text: '7');
    final emailCtrl = TextEditingController(
        text: Supabase.instance.client.auth.currentUser?.email ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit Profile', style: _textStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFA855F7)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(child: Text(_childAvatar, style: const TextStyle(fontSize: 40))),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Display Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Age',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: _textStyle(fontSize: 16, color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              setState(() => _childName = nameCtrl.text);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B21A8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Save', style: _textStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
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
        title: Text('Change Password', style: _textStyle(fontSize: 24, fontWeight: FontWeight.w700)),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: _textStyle(fontSize: 16, color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated!')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B21A8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Save', style: _textStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showShareCodeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Share Code', style: _textStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF6B21A8).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.construction_rounded, color: Color(0xFF6B21A8), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Coming Soon!\nTherapist linking via share code is under development.',
                          style: _textStyle(fontSize: 15, color: const Color(0xFF6B21A8))),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close', style: _textStyle(fontSize: 16, color: Colors.grey))),
        ],
      ),
    );
  }

  void _showParentPinDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Parent Gate PIN', style: _textStyle(fontSize: 24, fontWeight: FontWeight.w700)),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    counterText: '',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: _textStyle(fontSize: 16, color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN saved!')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B21A8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Save PIN', style: _textStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
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
        title: Text('Log Out', style: _textStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to sign out?',
            style: _textStyle(fontSize: 18, color: Colors.grey[700]!)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: _textStyle(fontSize: 16, color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Supabase.instance.client.auth.signOut();
              if (mounted) context.go('/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Log Out', style: _textStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
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
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Text('Deactivate Account', style: _textStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.red)),
          ],
        ),
        content: Text(
            'This will permanently deactivate your account and erase your data. This action cannot be undone.\n\nAre you sure you want to proceed?',
            style: _textStyle(fontSize: 17, color: Colors.grey[700]!)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: _textStyle(fontSize: 16, color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Delete user profile from Supabase
              try {
                final userId = Supabase.instance.client.auth.currentUser?.id;
                if (userId != null) {
                  await Supabase.instance.client.from('profiles').delete().eq('id', userId);
                }
                await Supabase.instance.client.auth.signOut();
              } catch (_) {}
              if (mounted) context.go('/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Deactivate', style: _textStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
