import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // NEW
import '../features/caregiver/presentation/screens/progress_dashboard_screen.dart';

class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({super.key});

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  int _selectedNavIndex = 0;
  String _caregiverName = 'Caregiver';
  String _caregiverAvatar = '😊';

  @override
  void initState() {
    super.initState();
    _loadCaregiverProfile();
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
    return GoogleFonts.poppins(
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
                width: 280,
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
                    // Logo
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child:
                              const Text('🌈', style: TextStyle(fontSize: 30)),
                        ),
                        const SizedBox(width: 15),
                        Text(
                          'EmoLor',
                          style: _textStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // Nav Items
                    _buildNavItem(
                        Icons.dashboard, 'Dashboard', _selectedNavIndex == 0,
                        () {
                      setState(() => _selectedNavIndex = 0);
                    }),
                    _buildNavItem(
                        Icons.bar_chart, 'Progress', _selectedNavIndex == 1,
                        () {
                      setState(() => _selectedNavIndex = 1);
                    }),
                    _buildNavItem(Icons.calendar_today, 'Schedule',
                        _selectedNavIndex == 2, () {
                      setState(() => _selectedNavIndex = 2);
                    }),

                    const Spacer(),

                    // Profile — tappable to navigate to profile screen
                    GestureDetector(
                      onTap: () => context.push('/profile'),
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(_caregiverAvatar,
                                    style: const TextStyle(fontSize: 25)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _caregiverName,
                                    style: _textStyle(
                                        fontSize: 16, color: Colors.white),
                                  ),
                                  Text(
                                    'View Profile',
                                    style: _textStyle(
                                        fontSize: 13,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w400),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: Colors.white70, size: 22),
                          ],
                        ),
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
                        ? _buildScheduleTab()
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(35),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Welcome back! 👋',
                                          style: _textStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF6B21A8),
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          'Here\'s an overview of your child\'s progress',
                                          style: _textStyle(
                                              fontSize: 16,
                                              color: Colors.grey[600]!),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        _buildHeaderButton(
                                            Icons.notifications_outlined, '3'),
                                        const SizedBox(width: 15),
                                        _buildHeaderButton(
                                            Icons.message_outlined, '2'),
                                      ],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 35),

                                // Stats Cards
                                Row(
                                  children: [
                                    _buildStatCard('😊', 'Mood Score', '85%',
                                        Colors.green, '+5% from last week'),
                                    const SizedBox(width: 20),
                                    _buildStatCard('🎮', 'Activities', '12',
                                        Colors.blue, 'Completed today'),
                                    const SizedBox(width: 20),
                                    _buildStatCard('⭐', 'Stars Earned', '127',
                                        Colors.orange, '15 new today'),
                                    const SizedBox(width: 20),
                                    _buildStatCard('🗣️', 'Express Cards', '28',
                                        Colors.purple, 'Used this week'),
                                  ],
                                ),

                                const SizedBox(height: 35),

                                // Main Content Row
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Left Column
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        children: [
                                          // Recent Activity (DYNAMIC)
                                          _buildCard(
                                            'Recent Activity',
                                            Icons.history,
                                            FutureBuilder<
                                                List<Map<String, dynamic>>>(
                                              future: _fetchRecentActivities(),
                                              builder: (context, snapshot) {
                                                if (snapshot.connectionState ==
                                                    ConnectionState.waiting) {
                                                  return const Center(
                                                      child:
                                                          CircularProgressIndicator());
                                                }
                                                if (snapshot.hasError) {
                                                  return Text(
                                                      'Error loading activity: ${snapshot.error}');
                                                }
                                                final activities =
                                                    snapshot.data ?? [];

                                                if (activities.isEmpty) {
                                                  return const Padding(
                                                    padding:
                                                        EdgeInsets.all(20.0),
                                                    child: Text(
                                                        "No meaningful activity recorded yet."),
                                                  );
                                                }

                                                return Column(
                                                  children: activities
                                                      .map((activity) {
                                                    final gameType =
                                                        activity['game_type'] ??
                                                            'Unknown';
                                                    final score =
                                                        activity['score'] ?? 0;
                                                    final timestamp =
                                                        activity['created_at'];

                                                    // Basic mapping for visual variety
                                                    String emoji = '🎮';
                                                    Color color = Colors.blue;
                                                    String title =
                                                        'Played $gameType (Score: $score)';

                                                    if (gameType == 'match') {
                                                      emoji = '🧩';
                                                      color = Colors.purple;
                                                    }

                                                    return _buildActivityItem(
                                                      emoji,
                                                      title,
                                                      timestamp != null
                                                          ? _timeAgo(timestamp)
                                                          : 'Recently',
                                                      color,
                                                    );
                                                  }).toList(),
                                                );
                                              },
                                            ),
                                          ),

                                          const SizedBox(height: 25),

                                          // Emotion Trends
                                          _buildCard(
                                            'Emotion Trends',
                                            Icons.insights,
                                            Column(
                                              children: [
                                                _buildEmotionBar(
                                                    'Happy', 0.8, Colors.green),
                                                _buildEmotionBar(
                                                    'Calm', 0.65, Colors.blue),
                                                _buildEmotionBar('Excited',
                                                    0.45, Colors.orange),
                                                _buildEmotionBar(
                                                    'Tired', 0.25, Colors.grey),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(width: 25),

                                    // Right Column
                                    Expanded(
                                      flex: 1,
                                      child: Column(
                                        children: [
                                          // Child Profile
                                          _buildCard(
                                            'Child Profile',
                                            Icons.person,
                                            Column(
                                              children: [
                                                Container(
                                                  width: 80,
                                                  height: 80,
                                                  decoration: BoxDecoration(
                                                    gradient:
                                                        const LinearGradient(
                                                      colors: [
                                                        Color(0xFFFFB74D),
                                                        Color(0xFFFF8A65)
                                                      ],
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                    border: Border.all(
                                                        color: Colors.white,
                                                        width: 4),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.orange
                                                            .withValues(
                                                                alpha: 0.3),
                                                        blurRadius: 15,
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Center(
                                                    child: Text('😊',
                                                        style: TextStyle(
                                                            fontSize: 45)),
                                                  ),
                                                ),
                                                const SizedBox(height: 15),
                                                Text(
                                                  'Thanesh',
                                                  style: _textStyle(
                                                      fontSize: 22,
                                                      fontWeight:
                                                          FontWeight.w700),
                                                ),
                                                Text(
                                                  'Level 5 Explorer',
                                                  style: _textStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[500]!),
                                                ),
                                                const SizedBox(height: 20),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceEvenly,
                                                  children: [
                                                    _buildProfileStat(
                                                        '⭐', '127'),
                                                    _buildProfileStat(
                                                        '🏅', '8'),
                                                    _buildProfileStat(
                                                        '📅', '14'),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),

                                          const SizedBox(height: 25),

                                          // Quick Actions
                                          _buildCard(
                                            'Quick Actions',
                                            Icons.flash_on,
                                            Column(
                                              children: [
                                                _buildQuickAction(
                                                    '📊',
                                                    'View Full Report',
                                                    Colors.blue),
                                                _buildQuickAction('📝',
                                                    'Add Note', Colors.green),
                                                _buildQuickAction('🎯',
                                                    'Set Goal', Colors.orange),
                                                _buildQuickAction(
                                                    '📞',
                                                    'Contact Therapist',
                                                    Colors.purple),
                                                _buildQuickAction(
                                                    '📅',
                                                    'Request Session',
                                                    const Color(0xFF6B21A8),
                                                    onTap: () => context.push(
                                                        '/request-session')),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      IconData icon, String label, bool isActive, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
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
            Text(
              label,
              style: _textStyle(
                fontSize: 16,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: Colors.white,
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 10,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.grey[700], size: 24),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
            child: Text(
              badge,
              style: _textStyle(
                  fontSize: 11,
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
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
                Icon(Icons.trending_up, color: color, size: 22),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              value,
              style: _textStyle(fontSize: 32, fontWeight: FontWeight.w700),
            ),
            Text(
              title,
              style: _textStyle(fontSize: 15, color: Colors.grey[600]!),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: _textStyle(
                  fontSize: 13, color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, IconData icon, Widget child) {
    return Container(
      padding: const EdgeInsets.all(25),
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
              const SizedBox(width: 12),
              Text(
                title,
                style: _textStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
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
                        _textStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text(time,
                    style: _textStyle(fontSize: 13, color: Colors.grey[500]!)),
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
              Text(emotion, style: _textStyle(fontSize: 15)),
              Text('${(value * 100).toInt()}%',
                  style: _textStyle(fontSize: 14, color: color)),
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
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Text(label,
                style: _textStyle(
                    fontSize: 15, color: color, fontWeight: FontWeight.w600)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  // ── Schedule Tab ──────────────────────────────────────────────────

  Widget _buildScheduleTab() {
    return Padding(
      padding: const EdgeInsets.all(35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule',
            style: _textStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6B21A8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'View and manage upcoming sessions',
            style: _textStyle(fontSize: 15, color: Colors.grey[600]!),
          ),
          const SizedBox(height: 30),
          // Request session button
          SizedBox(
            width: 260,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/request-session'),
              icon: const Icon(Icons.add_circle_outline),
              label: Text('Request New Session',
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
          // Upcoming sessions placeholder
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(30),
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
                  Row(
                    children: [
                      const Icon(Icons.event_note,
                          color: Color(0xFF6B21A8), size: 24),
                      const SizedBox(width: 12),
                      Text('Upcoming Sessions',
                          style: _textStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const Text('📅', style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 16),
                  Text(
                    'No upcoming sessions',
                    style: _textStyle(fontSize: 18, color: Colors.grey[500]!),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Request a session with your therapist to get started',
                    style: _textStyle(
                        fontSize: 14,
                        color: Colors.grey[400]!,
                        fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
