import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // NEW
import '../features/auth/presentation/providers/auth_provider.dart'; // NEW
import '../core/services/star_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'play_screen.dart';
import 'draw_screen.dart';
import 'express_cards_screen.dart';
import '../features/child/presentation/my_colours_screen.dart';
import 'rewards_screen.dart';
import '../core/widgets/parent_gate_dialog.dart';

class ChildDashboard extends ConsumerStatefulWidget {
  final bool showSwitchAccount;
  final String? childName;

  const ChildDashboard({
    super.key,
    this.showSwitchAccount = false,
    this.childName,
  });

  @override
  ConsumerState<ChildDashboard> createState() => _ChildDashboardState();
}

class _ChildDashboardState extends ConsumerState<ChildDashboard> with SingleTickerProviderStateMixin {

  String? _resolvedChildName;
  String? _avatarEmoji;
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnim;
  late final Animation<Color?> _colorAnim;

  @override
  void initState() {
    super.initState();
    _resolvedChildName = widget.childName;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.12)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_pulseController);
    _colorAnim = ColorTween(
      begin: Colors.white,
      end: Colors.white,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    if (_resolvedChildName == null) {
      _fetchChildName();
    }
    _pulseController.repeat(reverse: true);
  }


  Future<void> _fetchChildName() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final userId = user.id;

      // Use get_user_role RPC (SECURITY DEFINER — bypasses RLS)
      final rpcResult = await Supabase.instance.client
          .rpc('get_user_role', params: {'p_user_id': userId});
      if (mounted && rpcResult is List && rpcResult.isNotEmpty) {
        final row = rpcResult.first as Map<String, dynamic>;
        final name = row['full_name'] as String?;
        if (name != null && name.isNotEmpty) {
          setState(() => _resolvedChildName = name);
        }
        final av = row['avatar_url'] as String?;
        if (av != null && av.isNotEmpty) {
          setState(() => _avatarEmoji = av);
        }
      }

      // 3. Fallback: auth user metadata
      if (_resolvedChildName == null || _resolvedChildName!.isEmpty) {
        final metaName = user.userMetadata?['full_name'] as String?;
        if (mounted && metaName != null && metaName.isNotEmpty) {
          setState(() => _resolvedChildName = metaName);
        }
      }
    } catch (e) {
      debugPrint('Error fetching child profile: $e');
      // Last resort fallback from auth metadata
      final user = Supabase.instance.client.auth.currentUser;
      final metaName = user?.userMetadata?['full_name'] as String?;
      if (mounted && metaName != null && metaName.isNotEmpty) {
        setState(() => _resolvedChildName = metaName);
      }
    }
  }

  Future<void> _openScreenAndRefresh(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // Child-friendly text style helper
  TextStyle _cuteTextStyle({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w700,
    Color color = Colors.white,
    List<Shadow>? shadows,
  }) {
    return GoogleFonts.baloo2(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      shadows: shadows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          // Vibrant Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF7DD3FC), // Bright sky blue
                  Color(0xFFFDE68A), // Warm yellow sunset
                  Color(0xFF86EFAC), // Fresh grass green
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Decorative Hills
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(screenWidth, 300),
              painter: HillsPainter(),
            ),
          ),

          // Top Right: Switch Account button (org only)
          if (widget.showSwitchAccount)
            Positioned(
              top: 40,
              right: 25,
              child: GestureDetector(
                onTap: () => context.go('/orgz-child-dashboard'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withValues(alpha: 0.5),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.swap_horiz_rounded,
                          color: Colors.white, size: 26),
                      const SizedBox(width: 8),
                      Text(
                        'Switch',
                        style: _cuteTextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Title Banner
          Positioned(
            top: 32,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF8B5CF6),
                    Color(0xFF7C3AED),
                    Color(0xFF6D28D9)
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8), width: 3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(
                  height: 48,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final titleText = 'WELCOME TO EMOLOR, ${(_resolvedChildName ?? 'CHILD').toUpperCase()}';
                      final avatarText = ' ${_avatarEmoji ?? '😊'}';
                      final baseStyle = GoogleFonts.fredoka(
                        fontSize: 37,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      );
                      return Transform.scale(
                        scale: _scaleAnim.value,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Title text with gold shiny outline
                            Stack(
                              children: [
                                // Gold outline (stroke)
                                Text(
                                  titleText,
                                  style: baseStyle.copyWith(
                                    foreground: Paint()
                                      ..style = PaintingStyle.stroke
                                      ..strokeWidth = 2.5
                                      ..color = const Color(0xFFFFD700),
                                  ),
                                ),
                                // White fill on top
                                Text(
                                  titleText,
                                  style: baseStyle.copyWith(
                                    color: _colorAnim.value,
                                    shadows: const [
                                      Shadow(
                                        offset: Offset(2, 2),
                                        blurRadius: 6,
                                        color: Colors.black38,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // Avatar emoji — normal, no outline
                            Text(
                              avatarText,
                              style: const TextStyle(fontSize: 37),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                ),
              ),
            ),
          ),

          // 5 Action Buttons - 3 top + 2 bottom, all uniform large size
          Positioned(
            top: 180,
            left: 0,
            right: 0,
            bottom: 80,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top row: Play, Draw, Express
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      emoji: '🎮',
                      label: 'Play',
                      gradientColors: [
                        const Color(0xFFFB923C),
                        const Color(0xFFEF4444),
                      ],
                      shadowColor: Colors.orange,
                      onTap: () => _openScreenAndRefresh(const PlayScreen()),
                    ),
                    _buildActionButton(
                      emoji: '🖌️',
                      label: 'Draw',
                      gradientColors: [
                        const Color(0xFF60A5FA),
                        const Color(0xFF3B82F6),
                      ],
                      shadowColor: Colors.blue,
                      onTap: () => _openScreenAndRefresh(const DrawScreen()),
                    ),
                    _buildActionButton(
                      emoji: '🗣️',
                      label: 'Express',
                      gradientColors: [
                        const Color(0xFFA78BFA),
                        const Color(0xFF8B5CF6),
                      ],
                      shadowColor: Colors.purple,
                      onTap: () =>
                          _openScreenAndRefresh(const ExpressCardsScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Bottom row: My Colors, Rewards
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const SizedBox(width: 40),
                    _buildActionButton(
                      emoji: '🎨',
                      label: 'My Colors',
                      gradientColors: [
                        const Color(0xFFF472B6),
                        const Color(0xFFEC4899),
                      ],
                      shadowColor: Colors.pink,
                      onTap: () =>
                          _openScreenAndRefresh(const MyColoursScreen()),
                    ),
                    _buildActionButton(
                      emoji: '🎁',
                      label: 'Rewards',
                      gradientColors: [
                        const Color(0xFF34D399),
                        const Color(0xFF10B981),
                      ],
                      shadowColor: Colors.teal,
                      onTap: () => _openScreenAndRefresh(const RewardsScreen()),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ],
            ),
          ),

          // Bottom Left: Logout
          Positioned(
            bottom: 18,
            left: 18,
            child: GestureDetector(
              onTap: () => _confirmLogout(context, ref),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFFF6B6B), width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.logout_rounded,
                        color: Color(0xFFFF6B6B), size: 25),
                    const SizedBox(width: 7),
                    Text(
                      'Logout',
                      style: GoogleFonts.fredoka(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFF6B6B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Right: Caregiver + Profile Switcher (org only)
          Positioned(
            bottom: 18,
            right: 18,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Profile Switcher — only for org accounts
                if (widget.showSwitchAccount)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => context.go('/orgz-child-dashboard'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.switch_account_rounded,
                                color: Colors.white, size: 25),
                            const SizedBox(width: 7),
                            Text(
                              'Switch',
                              style: GoogleFonts.fredoka(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Caregiver button
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => ParentGateDialog(
                        onSuccess: () {
                          context.push('/caregiver-dashboard', extra: {
                            'childName': _resolvedChildName,
                            'showSwitch': widget.showSwitchAccount,
                          });
                        },
                      ),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6B21A8), Color(0xFF4C1D95)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.family_restroom,
                            color: Colors.white, size: 25),
                        const SizedBox(width: 7),
                        Text(
                          'Caregiver',
                          style: GoogleFonts.fredoka(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
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
    );
  }

  // Uniform action button for all 5 buttons
  Widget _buildActionButton({
    required String emoji,
    required String label,
    required List<Color> gradientColors,
    required Color shadowColor,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 169,
            height: 169,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: shadowColor.withValues(alpha: 0.5),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
              border: Border.all(color: Colors.white, width: 6),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 78)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Stack(
          children: [
            // Outline/stroke layer
            Text(
              label,
              style: _cuteTextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                shadows: const [],
              ).copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3
                  ..color = Colors.black54,
              ),
            ),
            // Fill layer
            Text(
              label,
              style: _cuteTextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                shadows: const [
                  Shadow(
                      offset: Offset(2, 2),
                      blurRadius: 6,
                      color: Colors.black54),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        contentPadding: const EdgeInsets.fromLTRB(32, 20, 32, 12),
        actionsPadding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
        titlePadding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
        title: Text('Log Out?',
            style:
                GoogleFonts.fredoka(fontSize: 30, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.fredoka(fontSize: 21),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel',
                style: GoogleFonts.fredoka(fontSize: 20, color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(authProvider.notifier).signOut();
            },
            child: Text('Log Out',
                style: GoogleFonts.fredoka(fontSize: 20, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class HillsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backHillPaint = Paint()
      ..color = const Color(0xFF4ADE80)
      ..style = PaintingStyle.fill;

    final backHill = Path();
    backHill.moveTo(0, size.height);
    backHill.quadraticBezierTo(size.width * 0.25, size.height * 0.3,
        size.width * 0.5, size.height * 0.6);
    backHill.quadraticBezierTo(
        size.width * 0.75, size.height * 0.2, size.width, size.height * 0.5);
    backHill.lineTo(size.width, size.height);
    backHill.close();
    canvas.drawPath(backHill, backHillPaint);

    final frontHillPaint = Paint()
      ..color = const Color(0xFF86EFAC)
      ..style = PaintingStyle.fill;

    final frontHill = Path();
    frontHill.moveTo(0, size.height);
    frontHill.quadraticBezierTo(size.width * 0.3, size.height * 0.5,
        size.width * 0.6, size.height * 0.7);
    frontHill.quadraticBezierTo(
        size.width * 0.85, size.height * 0.4, size.width, size.height * 0.6);
    frontHill.lineTo(size.width, size.height);
    frontHill.close();
    canvas.drawPath(frontHill, frontHillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
