import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import 'presentation/user_management_screen.dart';
import 'presentation/admin_overview_screen.dart';
import 'presentation/content_management_screen.dart';
import 'presentation/activity_editor_screen.dart';
import 'presentation/reward_library_screen.dart';
import 'presentation/moderation_queue_screen.dart';
import 'presentation/communication_config_screen.dart';
import 'presentation/session_oversight_screen.dart';

/// Admin Dashboard with sidebar navigation.
/// UCD009 – User Management tab.
/// UCD010 – Overview tab with system stats.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedIndex = 0; // 0 = Overview, 1 = User Management

  // Page bodies
  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard, label: 'Overview'),
    _NavItem(icon: Icons.people, label: 'User Management'),
    _NavItem(icon: Icons.photo_library, label: 'Content Library'),
    _NavItem(icon: Icons.edit_note, label: 'Activity Editor'),
    _NavItem(icon: Icons.emoji_events, label: 'Reward Library'),
    _NavItem(icon: Icons.shield_outlined, label: 'Moderation'),
    _NavItem(icon: Icons.settings, label: 'Comm Config'),
    _NavItem(icon: Icons.calendar_month, label: 'Session Oversight'),
  ];

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 1:
        return const UserManagementScreen();
      case 2:
        return const ContentManagementScreen();
      case 3:
        return const ActivityEditorScreen();
      case 4:
        return const RewardLibraryScreen();
      case 5:
        return const ModerationQueueScreen();
      case 6:
        return const CommunicationConfigScreen();
      case 7:
        return const SessionOversightScreen();
      default:
        return const AdminOverviewScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ── Sidebar ───────────────────────────────────────────────
          Container(
            width: 240,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1E40AF), Color(0xFF1E3A8A)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Logo area
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shield,
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Text('EmoLor Admin',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            )),
                      ],
                    ),
                  ),

                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 12),

                  // Navigation items
                  ..._navItems.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    final isSelected = _selectedIndex == i;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 3),
                      child: Material(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(() => _selectedIndex = i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Icon(item.icon,
                                    color: Colors.white
                                        .withValues(alpha: isSelected ? 1.0 : 0.7),
                                    size: 22),
                                const SizedBox(width: 14),
                                Text(
                                  item.label,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white
                                        .withValues(alpha: isSelected ? 1.0 : 0.7),
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  const Spacer(),

                  // Profile button
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => context.push('/profile'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.person_outline,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  size: 22),
                              const SizedBox(width: 14),
                              Text('Profile',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 15)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Logout button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 3, 12, 20),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _confirmLogout(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.logout,
                                  color: Colors.red.shade200, size: 22),
                              const SizedBox(width: 14),
                              Text('Logout',
                                  style: GoogleFonts.poppins(
                                      color: Colors.red.shade200,
                                      fontSize: 15)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Main content ──────────────────────────────────────────
          Expanded(
            child: Container(
              color: const Color(0xFFF8FAFC),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Log Out?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to log out?',
            style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).signOut();
            },
            child: Text('Log Out',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
