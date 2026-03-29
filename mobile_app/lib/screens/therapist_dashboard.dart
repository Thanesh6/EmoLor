import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/caregiver/presentation/screens/chat_tab.dart';
import '../features/therapist/presentation/screens/sessions_hub_tab.dart';
import '../features/therapist/presentation/screens/schedule_session_screen.dart';
import '../features/therapist/presentation/screens/my_clients_screen.dart';
import '../features/therapist/presentation/screens/therapist_engagement_tab.dart';
import '../features/therapist/presentation/screens/therapist_assessments_tab.dart';
import '../features/therapist/presentation/screens/therapist_settings_tab.dart';
import '../features/therapist/services/therapist_session_service.dart';

class TherapistDashboard extends StatefulWidget {
  const TherapistDashboard({super.key});

  @override
  State<TherapistDashboard> createState() => _TherapistDashboardState();
}

class _TherapistDashboardState extends State<TherapistDashboard>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = 0;
  int _pendingCount = 0;
  late AnimationController _glowCtrl;
  String _therapistName = 'Therapist';

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadPendingCount();
    _loadTherapistName();
  }

  Future<void> _loadTherapistName() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final metaName = user?.userMetadata?['full_name'] as String?;
      if (metaName != null && metaName.isNotEmpty) {
        if (mounted) setState(() => _therapistName = metaName);
        return;
      }
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('full_name')
            .eq('user_id', user.id)
            .maybeSingle();
        final name = profile?['full_name'] as String?;
        if (name != null && name.isNotEmpty && mounted) {
          setState(() => _therapistName = name);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPendingCount() async {
    final count = await TherapistSessionService().getPendingCount();
    if (mounted) setState(() => _pendingCount = count);
  }

  final List<Map<String, dynamic>> _patients = [
    {
      'name': 'Thanesh',
      'avatar': '😊',
      'mood': 'Happy',
      'lastSession': 'Today',
      'progress': 0.85,
      'color': Colors.green
    },
    {
      'name': 'Sarah',
      'avatar': '🦁',
      'mood': 'Calm',
      'lastSession': 'Yesterday',
      'progress': 0.72,
      'color': Colors.blue
    },
    {
      'name': 'Alex',
      'avatar': '🐰',
      'mood': 'Excited',
      'lastSession': '2 days ago',
      'progress': 0.65,
      'color': Colors.orange
    },
    {
      'name': 'Emma',
      'avatar': '🦊',
      'mood': 'Good',
      'lastSession': '3 days ago',
      'progress': 0.58,
      'color': Colors.purple
    },
  ];

  final List<Map<String, dynamic>> _todaySchedule = [
    {
      'time': '9:00 AM',
      'patient': 'Thanesh',
      'type': 'Regular Session',
      'status': 'completed'
    },
    {
      'time': '10:30 AM',
      'patient': 'Sarah',
      'type': 'Progress Review',
      'status': 'completed'
    },
    {
      'time': '2:00 PM',
      'patient': 'Alex',
      'type': 'Assessment',
      'status': 'upcoming'
    },
    {
      'time': '4:00 PM',
      'patient': 'Emma',
      'type': 'Regular Session',
      'status': 'upcoming'
    },
  ];

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
              Color(0xFFF0F9FF),
              Color(0xFFE0E7FF),
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
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1E40AF), Color(0xFF1E3A8A)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Glowing EMOLOR title
                    Center(
                      child: AnimatedBuilder(
                        animation: _glowCtrl,
                        builder: (context, _) {
                          final glow = 8.0 + _glowCtrl.value * 12.0;
                          return Text(
                            'EMOLOR',
                            style: GoogleFonts.fredoka(
                              fontSize: 52,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.white.withValues(alpha: 0.6 + _glowCtrl.value * 0.4),
                                  blurRadius: glow,
                                ),
                                Shadow(
                                  color: const Color(0xFFBFDBFE).withValues(alpha: 0.5),
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
                        'THERAPIST PORTAL',
                        style: _textStyle(
                            fontSize: 11,
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
                              Icons.home_rounded,
                              'Home',
                              _selectedNavIndex == 0,
                              () => setState(() => _selectedNavIndex = 0)),
                          _buildNavItem(
                              Icons.people,
                              'Patients',
                              _selectedNavIndex == 1,
                              () => setState(() => _selectedNavIndex = 1)),
                          _buildNavItem(
                              Icons.calendar_month,
                              'Sessions',
                              _selectedNavIndex == 2,
                              () => setState(() => _selectedNavIndex = 2),
                              badgeCount: _pendingCount),
                          _buildNavItem(
                              Icons.assessment,
                              'Reports',
                              _selectedNavIndex == 3,
                              () => setState(() => _selectedNavIndex = 3)),
                          _buildNavItem(Icons.psychology, 'Assessments',
                              _selectedNavIndex == 4,
                              () => setState(() => _selectedNavIndex = 4)),
                          _buildNavItem(
                              Icons.chat_bubble_outline,
                              'Messages',
                              _selectedNavIndex == 5,
                              () => setState(() => _selectedNavIndex = 5)),
                          _buildNavItem(Icons.settings, 'Settings',
                              _selectedNavIndex == 6,
                              () => setState(() => _selectedNavIndex = 6)),
                        ],
                      ),
                    ),

                    // Logout button
                    GestureDetector(
                      onTap: () async {
                        await Supabase.instance.client.auth.signOut();
                        if (context.mounted) context.go('/login');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              'Logout',
                              style: _textStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: _selectedNavIndex == 5
                    ? const ChatTab()
                    : _selectedNavIndex == 2
                        ? const SessionsHubTab()
                        : _selectedNavIndex == 1
                            ? const MyClientsScreen()
                            : _selectedNavIndex == 3
                                ? const TherapistEngagementTab()
                                : _selectedNavIndex == 4
                                    ? const TherapistAssessmentsTab()
                                    : _selectedNavIndex == 6
                                        ? const TherapistSettingsTab()
                                        : Padding(
                                    padding: const EdgeInsets.fromLTRB(28, 16, 28, 16),
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
                                                Text(
                                                  'Good Morning, $_therapistName! 👋',
                                                  style: _textStyle(fontSize: 26, fontWeight: FontWeight.w700, color: const Color(0xFF1E3A8A)),
                                                ),
                                                Text(
                                                  'Here\'s your practice overview for today',
                                                  style: _textStyle(fontSize: 14, color: Colors.grey[600]!),
                                                ),
                                              ],
                                            ),
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScheduleSessionScreen()));
                                              },
                                              icon: const Icon(Icons.add, size: 22, color: Colors.white),
                                              label: Text('New Session', style: _textStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w700)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF1E40AF),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 12),

                                        // Stats Cards
                                        Row(
                                          children: [
                                            _buildStatCard('👥', 'Active Patients', '12', const Color(0xFF1E40AF)),
                                            const SizedBox(width: 14),
                                            _buildStatCard('📅', 'Sessions Today', '4', const Color(0xFF059669)),
                                            const SizedBox(width: 14),
                                            _buildStatCard('📊', 'Avg. Progress', '73%', const Color(0xFFD97706)),
                                            const SizedBox(width: 14),
                                            _buildStatCard('📝', 'Pending Reports', '3', const Color(0xFFDC2626)),
                                          ],
                                        ),

                                        const SizedBox(height: 12),

                                        // Main Content Row — fills remaining space
                                        Expanded(
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              // Left — Patient Overview
                                              Expanded(
                                                flex: 3,
                                                child: _buildCard(
                                                  'Patient Overview',
                                                  Icons.people,
                                                  Column(
                                                    children: _patients.map((p) => _buildPatientRow(p)).toList(),
                                                  ),
                                                ),
                                              ),

                                              const SizedBox(width: 18),

                                              // Right — Schedule + Quick Actions (equal height)
                                              Expanded(
                                                flex: 2,
                                                child: Column(
                                                  children: [
                                                    Expanded(
                                                      flex: 1,
                                                      child: _buildCard(
                                                        "Today's Schedule",
                                                        Icons.calendar_today,
                                                        Column(
                                                          children: _todaySchedule.map((s) => _buildScheduleItem(s)).toList(),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 14),
                                                    Expanded(
                                                      flex: 1,
                                                      child: _buildCard(
                                                        'Quick Actions',
                                                        Icons.flash_on,
                                                        Column(
                                                          children: [
                                                            _buildQuickAction('📋', 'Create Assessment', const Color(0xFF1E40AF)),
                                                            _buildQuickAction('📊', 'Generate Report', const Color(0xFF059669)),
                                                            _buildQuickAction('💬', 'Send Message', const Color(0xFFD97706),
                                                                onTap: () => setState(() => _selectedNavIndex = 5)),
                                                            _buildQuickAction('📁', 'View All Records', const Color(0xFF7C3AED)),
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
                                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      IconData icon, String label, bool isActive, VoidCallback? onTap,
      {int badgeCount = 0}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                label,
                style: _textStyle(
                  fontSize: 18,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ),
            if (badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$badgeCount',
                  style: _textStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String emoji, String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 14),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: _textStyle(
                        fontSize: 38, fontWeight: FontWeight.w700, color: const Color(0xFF1E3A8A)),
                  ),
                  Text(
                    title,
                    style: _textStyle(fontSize: 15, color: Colors.grey[600]!),
                    overflow: TextOverflow.ellipsis,
                  ),
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
      padding: const EdgeInsets.all(16),
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
              Icon(icon, color: const Color(0xFF1E40AF), size: 26),
              const SizedBox(width: 12),
              Text(
                title,
                style: _textStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientRow(Map<String, dynamic> patient) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (patient['color'] as Color).withValues(alpha: 0.7),
                  patient['color']
                ],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child:
                  Text(patient['avatar'], style: const TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patient['name'],
                    style:
                        _textStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 15, color: Colors.grey[500]),
                    const SizedBox(width: 5),
                    Text('Last: ${patient['lastSession']}',
                        style:
                            _textStyle(fontSize: 14, color: Colors.grey[500]!)),
                    const SizedBox(width: 15),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: (patient['color'] as Color).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(patient['mood'],
                          style: _textStyle(
                              fontSize: 13, color: patient['color'])),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${(patient['progress'] * 100).toInt()}%',
                  style: _textStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: patient['color'])),
              const SizedBox(height: 8),
              SizedBox(
                width: 110,
                child: LinearProgressIndicator(
                  value: patient['progress'],
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(patient['color']),
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 18),
            color: Colors.grey[400],
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(Map<String, dynamic> session) {
    final isCompleted = session['status'] == 'completed';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.grey[50] : const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? Colors.grey[200]!
              : const Color(0xFF1E40AF).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.grey[200]
                  : const Color(0xFF1E40AF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              session['time'],
              style: _textStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color:
                    isCompleted ? Colors.grey[600]! : const Color(0xFF1E40AF),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session['patient'],
                  style: _textStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? Colors.grey[500]! : Colors.black87,
                  ),
                ),
                Text(
                  session['type'],
                  style: _textStyle(fontSize: 13, color: Colors.grey[500]!),
                ),
              ],
            ),
          ),
          Icon(
            isCompleted ? Icons.check_circle : Icons.schedule,
            color: isCompleted ? Colors.green : const Color(0xFF1E40AF),
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(String emoji, String label, Color color,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
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
}
