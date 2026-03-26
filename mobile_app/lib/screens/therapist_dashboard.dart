import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../features/caregiver/presentation/screens/chat_tab.dart';
import '../features/therapist/presentation/screens/sessions_hub_tab.dart';
import '../features/therapist/presentation/screens/schedule_session_screen.dart';
import '../features/therapist/presentation/screens/my_clients_screen.dart';
import '../features/therapist/presentation/screens/therapist_engagement_tab.dart';
import '../features/therapist/services/therapist_session_service.dart';

class TherapistDashboard extends StatefulWidget {
  const TherapistDashboard({super.key});

  @override
  State<TherapistDashboard> createState() => _TherapistDashboardState();
}

class _TherapistDashboardState extends State<TherapistDashboard> {
  int _selectedNavIndex = 0;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
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
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
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
                              const Text('🏥', style: TextStyle(fontSize: 30)),
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
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 35),

                    // Nav Items
                    _buildNavItem(
                        Icons.dashboard,
                        'Dashboard',
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
                        _selectedNavIndex == 4, null),
                    _buildNavItem(
                        Icons.chat_bubble_outline,
                        'Messages',
                        _selectedNavIndex == 5,
                        () => setState(() => _selectedNavIndex = 5)),
                    _buildNavItem(Icons.settings, 'Settings',
                        _selectedNavIndex == 6, null),

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
                              child: const Center(
                                child: Text('👩‍⚕️',
                                    style: TextStyle(fontSize: 25)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Therapist',
                                    style: _textStyle(
                                        fontSize: 15, color: Colors.white),
                                  ),
                                  Text(
                                    'View Profile',
                                    style: _textStyle(
                                        fontSize: 12,
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
                child: _selectedNavIndex == 5
                    ? const ChatTab()
                    : _selectedNavIndex == 2
                        ? const SessionsHubTab()
                        : _selectedNavIndex == 1
                            ? const MyClientsScreen()
                            : _selectedNavIndex == 3
                                ? const TherapistEngagementTab()
                                : SingleChildScrollView(
                                    padding: const EdgeInsets.all(35),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                                  'Good Morning, Dr. Johnson! 👋',
                                                  style: _textStyle(
                                                    fontSize: 30,
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        const Color(0xFF1E40AF),
                                                  ),
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                  'You have 4 sessions scheduled today',
                                                  style: _textStyle(
                                                      fontSize: 16,
                                                      color: Colors.grey[600]!),
                                                ),
                                              ],
                                            ),
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const ScheduleSessionScreen(),
                                                  ),
                                                );
                                              },
                                              icon: const Icon(Icons.add,
                                                  size: 22),
                                              label: Text('New Session',
                                                  style: _textStyle(
                                                      fontSize: 15,
                                                      color: Colors.white)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF1E40AF),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 25,
                                                        vertical: 18),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12)),
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 35),

                                        // Stats Cards
                                        Row(
                                          children: [
                                            _buildStatCard(
                                                '👥',
                                                'Active Patients',
                                                '12',
                                                const Color(0xFF1E40AF)),
                                            const SizedBox(width: 20),
                                            _buildStatCard(
                                                '📅',
                                                'Sessions Today',
                                                '4',
                                                const Color(0xFF059669)),
                                            const SizedBox(width: 20),
                                            _buildStatCard(
                                                '📊',
                                                'Avg. Progress',
                                                '73%',
                                                const Color(0xFFD97706)),
                                            const SizedBox(width: 20),
                                            _buildStatCard(
                                                '📝',
                                                'Pending Reports',
                                                '3',
                                                const Color(0xFFDC2626)),
                                          ],
                                        ),

                                        const SizedBox(height: 35),

                                        // Main Content Row
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Left Column - Patients
                                            Expanded(
                                              flex: 3,
                                              child: Column(
                                                children: [
                                                  // Patient Progress
                                                  _buildCard(
                                                    'Patient Overview',
                                                    Icons.people,
                                                    Column(
                                                      children: _patients
                                                          .map((p) =>
                                                              _buildPatientRow(
                                                                  p))
                                                          .toList(),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            const SizedBox(width: 25),

                                            // Right Column - Schedule
                                            Expanded(
                                              flex: 2,
                                              child: Column(
                                                children: [
                                                  // Today's Schedule
                                                  _buildCard(
                                                    "Today's Schedule",
                                                    Icons.calendar_today,
                                                    Column(
                                                      children: _todaySchedule
                                                          .map((s) =>
                                                              _buildScheduleItem(
                                                                  s))
                                                          .toList(),
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
                                                            '📋',
                                                            'Create Assessment',
                                                            const Color(
                                                                0xFF1E40AF)),
                                                        _buildQuickAction(
                                                            '📊',
                                                            'Generate Report',
                                                            const Color(
                                                                0xFF059669)),
                                                        _buildQuickAction(
                                                            '💬',
                                                            'Send Message',
                                                            const Color(
                                                                0xFFD97706),
                                                            onTap: () =>
                                                                setState(() =>
                                                                    _selectedNavIndex =
                                                                        5)),
                                                        _buildQuickAction(
                                                            '📁',
                                                            'View All Records',
                                                            const Color(
                                                                0xFF7C3AED)),
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
      IconData icon, String label, bool isActive, VoidCallback? onTap,
      {int badgeCount = 0}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                label,
                style: _textStyle(
                  fontSize: 16,
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
        padding: const EdgeInsets.all(22),
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
            const SizedBox(width: 18),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: _textStyle(
                        fontSize: 28, fontWeight: FontWeight.w700, color: color),
                  ),
                  Text(
                    title,
                    style: _textStyle(fontSize: 14, color: Colors.grey[600]!),
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
              Icon(icon, color: const Color(0xFF1E40AF), size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: _textStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text('View All',
                  style:
                      _textStyle(fontSize: 14, color: const Color(0xFF1E40AF))),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildPatientRow(Map<String, dynamic> patient) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
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
                  Text(patient['avatar'], style: const TextStyle(fontSize: 30)),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patient['name'],
                    style:
                        _textStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 5),
                    Text('Last: ${patient['lastSession']}',
                        style:
                            _textStyle(fontSize: 13, color: Colors.grey[500]!)),
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
                              fontSize: 12, color: patient['color'])),
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
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: patient['color'])),
              const SizedBox(height: 8),
              SizedBox(
                width: 100,
                child: LinearProgressIndicator(
                  value: patient['progress'],
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(patient['color']),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
          const SizedBox(width: 15),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          const SizedBox(width: 15),
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
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
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
