import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/emotion_colour_mapping.dart';
import '../features/caregiver/presentation/screens/chat_tab.dart';
import '../features/caregiver/presentation/screens/progress_dashboard_screen.dart';
import '../features/caregiver/presentation/widgets/new_goal_dialog.dart';

class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({super.key});

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = 0;
  String _caregiverName = 'Caregiver';
  String _caregiverAvatar = '😊';
  String _childName = 'Child';
  String _childAvatar = '🐱';
  late AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadCaregiverProfile();
    _loadChildProfile();
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadChildProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      // Try to load linked child profile
      final link = await Supabase.instance.client
          .from('caregiver_child_link')
          .select('child_id')
          .eq('caregiver_id', userId)
          .maybeSingle();
      if (link != null) {
        final childProfile = await Supabase.instance.client
            .from('profiles')
            .select('full_name, avatar_url')
            .eq('user_id', link['child_id'])
            .maybeSingle();
        if (mounted && childProfile != null) {
          setState(() {
            final name = childProfile['full_name'] as String?;
            if (name != null && name.isNotEmpty) _childName = name;
            final av = childProfile['avatar_url'] as String?;
            if (av != null && av.isNotEmpty) _childAvatar = av;
          });
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
                              fontSize: 51,
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
                    const SizedBox(height: 30),

                    // Nav Items — equally spaced
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNavItem(
                              Icons.home_rounded, 'Home', _selectedNavIndex == 0,
                              () {
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
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: _selectedNavIndex == 1
                    ? const ProgressDashboardScreen()
                    : _selectedNavIndex == 2
                        ? _buildGoalsRewardsTab()
                        : _selectedNavIndex == 3
                            ? const ChatTab()
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
                          PopupMenuItem(
                            enabled: false,
                            child: Text(
                              '\u{1F3AE} Thanesh completed EMOZZLE \u2014 2 mins ago',
                              style: _textStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                          PopupMenuItem(
                            enabled: false,
                            child: Text(
                              '\u2B50 3 new stars earned today',
                              style: _textStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                          PopupMenuItem(
                            enabled: false,
                            child: Text(
                              '\u{1F4AC} New message from Dr. Sarah',
                              style: _textStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      );
                    },
                    child: _buildHeaderButton(Icons.notifications_outlined, '3'),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedNavIndex = 3);
                    },
                    child: _buildHeaderButton(Icons.message_outlined, '2'),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Stats Cards — compact row
          Row(
            children: [
              _buildStatCard('😊', 'Mood', '85%', Colors.green, '+5%'),
              const SizedBox(width: 10),
              _buildStatCard('🎮', 'Activities', '12', Colors.blue, 'Today'),
              const SizedBox(width: 10),
              _buildStatCard('⭐', 'Stars', '127', Colors.orange, '+15'),
              const SizedBox(width: 10),
              _buildStatCard('🗣️', 'Express', '28', Colors.purple, 'This week'),
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
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: _fetchRecentActivities(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                              final activities = snapshot.data ?? [];
                              if (activities.isEmpty) {
                                // Show sample data so the card looks right
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildActivityItem('🧩', 'Played EMOZZLE (⭐3)', '5 mins ago', Colors.purple),
                                    _buildActivityItem('🫧', 'Played EMOPOP (⭐2)', '20 mins ago', Colors.blue),
                                    _buildActivityItem('🔤', 'Played EMOSPELL (⭐4)', '1 hour ago', Colors.green),
                                  ],
                                );
                              }
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: activities.take(3).map((a) {
                                  final game = a['game_type'] ?? 'Unknown';
                                  final score = a['score'] ?? 0;
                                  final ts = a['created_at'];
                                  return _buildActivityItem(
                                      '🎮',
                                      'Played $game ($score)',
                                      ts != null ? _timeAgo(ts) : 'Recently',
                                      Colors.blue);
                                }).toList(),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _buildCard(
                          'Emotion Trends',
                          Icons.insights,
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildEmotionBar('Happy', 0.8, Colors.green),
                              _buildEmotionBar('Calm', 0.65, Colors.blue),
                              _buildEmotionBar('Excited', 0.45, Colors.orange),
                              _buildEmotionBar('Tired', 0.25, Colors.grey),
                            ],
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
                            Text('Thanesh',
                                style: _textStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700)),
                            const Spacer(),
                            // Right: stats vertically
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('⭐ 127 Stars',
                                    style: _textStyle(
                                        fontSize: 15,
                                        color: Colors.orange[700]!,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text('🏅 8 Rewards',
                                    style: _textStyle(
                                        fontSize: 15,
                                        color: Colors.blue[700]!,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text('📅 14 Days',
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
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 15),
            Flexible(
              child: Text(
                label,
                style: _textStyle(
                  fontSize: 24,
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
              Icon(icon, color: const Color(0xFF6B21A8), size: 26),
              const SizedBox(width: 10),
              Text(
                title,
                style: _textStyle(fontSize: 22, fontWeight: FontWeight.w700),
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
        Text(emoji, style: const TextStyle(fontSize: 25)),
        const SizedBox(height: 5),
        Text(value,
            style: _textStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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

  Widget _buildChildColoursCard() {
    return FutureBuilder<void>(
      future: EmotionColourMapping.ensureLoaded(),
      builder: (context, snapshot) {
        return _buildCard(
          "My Child's Colours",
          Icons.palette,
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _emotionList.map((e) {
              final color = EmotionColourMapping.colorFor(e['name']!);
              final isDark = color.computeLuminance() < 0.4;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e['emoji']!, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(
                      e['name']!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ── Goals & Rewards Tab ────────────────────────────────────────────

  Widget _buildGoalsRewardsTab() {
    return Padding(
      padding: const EdgeInsets.all(35),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Goals & Rewards',
                style: _textStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6B21A8))),
            const SizedBox(height: 8),
            Text("Set targets and track your child's reward progress",
                style: _textStyle(fontSize: 18, color: Colors.grey[600]!)),
            const SizedBox(height: 30),

            // Create Goal button
            SizedBox(
              width: 240,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Open new goal dialog
                  showDialog(
                    context: context,
                    builder: (_) => const NewGoalDialog(),
                  );
                },
                icon: const Icon(Icons.add_circle_outline),
                label: Text('Create New Goal',
                    style: _textStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B21A8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Active Goals
            _buildCard(
              'Active Goals',
              Icons.flag_rounded,
              Column(
                children: [
                  _buildGoalRow('Complete 3 activities/week', 0.6, '3/5',
                      Colors.blue, '🎮'),
                  _buildGoalRow('Earn 10 stars', 0.4, '4/10', Colors.orange,
                      '⭐'),
                  _buildGoalRow('Log emotions daily', 0.85, '6/7',
                      Colors.green, '📝'),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // Earned Rewards
            _buildCard(
              'Earned Rewards',
              Icons.emoji_events_rounded,
              FutureBuilder<void>(
                future: EmotionColourMapping.ensureLoaded(),
                builder: (context, _) {
                  return Wrap(
                    spacing: 15,
                    runSpacing: 15,
                    children: [
                      _buildRewardChip('👣', 'First Steps', true),
                      _buildRewardChip('✨', 'Tiny Spark', true),
                      _buildRewardChip('😊', 'Happy Smile', false),
                      _buildRewardChip('🌟', 'Little Star', false),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalRow(
      String label, double progress, String progressText, Color color, String emoji) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(label,
                          style: _textStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                    Text(progressText,
                        style: _textStyle(
                            fontSize: 13,
                            color: Colors.grey[500]!,
                            fontWeight: FontWeight.w400)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: earned ? const Color(0xFFFFF3E0) : Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: earned ? Colors.orange.shade300 : Colors.grey.shade300,
            width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: _textStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(earned ? 'Earned ✓' : 'Locked',
                  style: _textStyle(
                      fontSize: 11,
                      color: earned ? Colors.green : Colors.grey[400]!,
                      fontWeight: FontWeight.w400)),
            ],
          ),
        ],
      ),
    );
  }

  // ── My Child Tab ─────────────────────────────────────────────────

  Widget _buildMyChildTab() {
    return Padding(
      padding: const EdgeInsets.all(35),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Child',
                style: _textStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6B21A8))),
            const SizedBox(height: 8),
            Text("View your child's profile, colours and avatar",
                style: _textStyle(fontSize: 18, color: Colors.grey[600]!)),
            const SizedBox(height: 30),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left — Child Profile Card
                Expanded(
                  child: _buildCard(
                    'Child Profile',
                    Icons.person,
                    Column(
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFFFFB74D), Color(0xFFFF8A65)]),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.orange.withValues(alpha: 0.3),
                                  blurRadius: 15),
                            ],
                          ),
                          child: const Center(
                              child: Text('😊',
                                  style: TextStyle(fontSize: 50))),
                        ),
                        const SizedBox(height: 16),
                        Text('Child',
                            style: _textStyle(
                                fontSize: 22, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Emoji Explorer',
                            style: _textStyle(
                                fontSize: 14, color: Colors.grey[500]!)),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildProfileStat('⭐', 'Stars'),
                            _buildProfileStat('🏅', 'Badges'),
                            _buildProfileStat('📅', 'Days'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 25),

                // Right — Colour-Emotion Mappings
                Expanded(child: _buildChildColoursCard()),
              ],
            ),

            const SizedBox(height: 25),

            // Recent Emotion Journal
            _buildCard(
              'Emotion Interaction Log',
              Icons.auto_stories_rounded,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Recent emotions your child interacted with during games",
                    style: _textStyle(
                        fontSize: 13,
                        color: Colors.grey[500]!,
                        fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildJournalChip('😊', 'Happy', 'EMOZZLE'),
                      _buildJournalChip('😢', 'Sad', 'EMOPOP'),
                      _buildJournalChip('😡', 'Angry', 'EMOSLASH'),
                      _buildJournalChip('😨', 'Scared', 'EMOCATCH'),
                      _buildJournalChip('🤩', 'Excited', 'EMOSPELL'),
                      _buildJournalChip('😌', 'Calm', 'EMOSORT'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJournalChip(String emoji, String emotion, String game) {
    final color = EmotionColourMapping.colorFor(emotion);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 5),
          Text(emotion,
              style: _textStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Text('· $game',
              style: _textStyle(
                  fontSize: 11,
                  color: Colors.grey[500]!,
                  fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }

  // ── Settings Tab ─────────────────────────────────────────────────

  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.all(35),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings',
                style: _textStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6B21A8))),
            const SizedBox(height: 8),
            Text('Manage your account, security and preferences',
                style: _textStyle(fontSize: 18, color: Colors.grey[600]!)),
            const SizedBox(height: 30),

            // Account section
            _buildCard(
              'Account',
              Icons.person_outline,
              Column(
                children: [
                  _buildSettingsRow(Icons.edit, 'Edit Profile',
                      'Update your name and avatar',
                      onTap: () => context.push('/profile')),
                  const Divider(height: 1),
                  _buildSettingsRow(Icons.lock_outline, 'Change Password',
                      'Update your login password'),
                  const Divider(height: 1),
                  _buildSettingsRow(Icons.link, 'Share Code',
                      'Generate a code to link with therapist',
                      onTap: () => setState(() => _selectedNavIndex = 3)),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // Security section
            _buildCard(
              'Security',
              Icons.shield_outlined,
              Column(
                children: [
                  _buildSettingsRow(Icons.pin, 'Parent Gate PIN',
                      'Set or change your 4-digit PIN'),
                  const Divider(height: 1),
                  _buildSettingsRow(Icons.fingerprint, 'Biometric Lock',
                      'Use fingerprint to access caregiver settings'),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // Notifications
            _buildCard(
              'Notifications',
              Icons.notifications_outlined,
              Column(
                children: [
                  _buildSettingsRow(Icons.message_outlined, 'Message Alerts',
                      'Get notified for new therapist messages'),
                  const Divider(height: 1),
                  _buildSettingsRow(Icons.emoji_events_outlined, 'Reward Alerts',
                      'Notify when child earns a reward'),
                  const Divider(height: 1),
                  _buildSettingsRow(Icons.calendar_today, 'Session Reminders',
                      'Reminders for upcoming therapy sessions'),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // Danger zone
            Center(
              child: TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.logout, color: Colors.red, size: 20),
                label: Text('Log Out',
                    style: _textStyle(
                        fontSize: 15,
                        color: Colors.red,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsRow(IconData icon, String title, String subtitle,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF6B21A8), size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: _textStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: _textStyle(
                          fontSize: 12,
                          color: Colors.grey[500]!,
                          fontWeight: FontWeight.w400)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 22),
          ],
        ),
      ),
    );
  }
}
