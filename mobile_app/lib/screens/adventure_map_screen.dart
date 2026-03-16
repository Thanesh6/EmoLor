import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // NEW
import '../features/auth/presentation/providers/auth_provider.dart'; // NEW
import '../core/services/star_service.dart';
import 'play_screen.dart';
import 'draw_screen.dart';
import 'express_cards_screen.dart';
import '../features/child/presentation/my_colours_screen.dart';
import 'rewards_screen.dart';
import '../core/widgets/parent_gate_dialog.dart';

class AdventureMapScreen extends ConsumerStatefulWidget {
  const AdventureMapScreen({super.key});

  @override
  ConsumerState<AdventureMapScreen> createState() => _AdventureMapScreenState();
}

class _AdventureMapScreenState extends ConsumerState<AdventureMapScreen>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  int _totalStars = 0;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _loadStars();
  }

  Future<void> _loadStars() async {
    final stars = await StarService.getTotalStars();
    if (mounted) setState(() => _totalStars = stars);
  }

  Future<void> _openScreenAndRefresh(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    await _loadStars();
  }

  @override
  void dispose() {
    _bounceController.dispose();
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
    final screenHeight = MediaQuery.of(context).size.height;

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
              size: Size(MediaQuery.of(context).size.width, 300),
              painter: HillsPainter(),
            ),
          ),

          // Top Left: Caregiver Mode / Profile
          Positioned(
            top: 40,
            left: 25,
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => ParentGateDialog(
                    onSuccess: () {
                      context.push('/caregiver-dashboard');
                    },
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6B21A8), Color(0xFF4C1D95)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.settings, color: Colors.white, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      'Caregiver',
                      style: _cuteTextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Top Right: Star Counter (tappable → Rewards)
          Positioned(
            top: 40,
            right: 25,
            child: GestureDetector(
              onTap: () => _openScreenAndRefresh(const RewardsScreen()),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                    const Text('⭐', style: TextStyle(fontSize: 32)),
                    const SizedBox(width: 10),
                    Text(
                      '$_totalStars ${_totalStars <= 1 ? 'Star' : 'Stars'}',
                      style: _cuteTextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        shadows: [
                          const Shadow(
                            offset: Offset(2, 2),
                            blurRadius: 4,
                            color: Color(0x88000000),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Welcome Text - CENTERED: "Welcome To EmoLor"
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  Text(
                    'Welcome To',
                    style: _cuteTextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.95),
                      shadows: const [
                        Shadow(
                            offset: Offset(2, 2),
                            blurRadius: 4,
                            color: Colors.black26),
                      ],
                    ),
                  ),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFFFF6B6B),
                        Color(0xFFFFE66D),
                        Color(0xFF4ECDC4)
                      ],
                    ).createShader(bounds),
                    child: Text(
                      'EmoLor! 🌈',
                      style: _cuteTextStyle(
                        fontSize: 55,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                              offset: Offset(3, 3),
                              blurRadius: 6,
                              color: Colors.black38),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Center: Bouncing Child Avatar - Name changed to Thanesh
          Positioned(
            top: 160,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _bounceController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -10 * _bounceController.value),
                  child: child,
                );
              },
              child: Center(
                child: Column(
                  children: [
                    // Avatar with glow
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFFFB74D).withValues(alpha: 0.6),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFFE0B2), Color(0xFFFFCC80)],
                          ),
                          border: Border.all(color: Colors.white, width: 6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            '😊',
                            style: TextStyle(fontSize: 70),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B9D), Color(0xFFC44569)],
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pink.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Text(
                        '✨ Thanesh ✨',
                        style: _cuteTextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // TOP ROW: 3 Big Icons (Play, Draw, Stories)
          Positioned(
            bottom: screenHeight * 0.21,
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBigActionButton(
                  emoji: '🎮',
                  label: 'Play',
                  gradientColors: [
                    const Color(0xFFFB923C),
                    const Color(0xFFEF4444)
                  ],
                  shadowColor: Colors.orange,
                  onTap: () => _openScreenAndRefresh(const PlayScreen()),
                ),
                _buildBigActionButton(
                  emoji: '🖌️',
                  label: 'Draw',
                  gradientColors: [
                    const Color(0xFF60A5FA),
                    const Color(0xFF3B82F6)
                  ],
                  shadowColor: Colors.blue,
                  onTap: () => _openScreenAndRefresh(const DrawScreen()),
                ),
                _buildBigActionButton(
                  emoji: '🗣️',
                  label: 'Express',
                  gradientColors: [
                    const Color(0xFFA78BFA),
                    const Color(0xFF8B5CF6)
                  ],
                  shadowColor: Colors.purple,
                  onTap: () =>
                      _openScreenAndRefresh(const ExpressCardsScreen()),
                ),
              ],
            ),
          ),

          // BOTTOM ROW: 2 Icons (My Colors, Rewards)
          Positioned(
            bottom: 15,
            left: 80, // Shifted right to make space for Logout
            right: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSmallActionButton(
                  emoji: '🎨',
                  label: 'My Colors',
                  gradientColors: [
                    const Color(0xFFF472B6),
                    const Color(0xFFEC4899)
                  ],
                  shadowColor: Colors.pink,
                  onTap: () => _openScreenAndRefresh(const MyColoursScreen()),
                ),
                _buildSmallActionButton(
                  emoji: '🎁',
                  label: 'Rewards',
                  gradientColors: [
                    const Color(0xFF34D399),
                    const Color(0xFF10B981)
                  ],
                  shadowColor: Colors.teal,
                  onTap: () => _openScreenAndRefresh(const RewardsScreen()),
                ),
              ],
            ),
          ),

          // Bottom Left: Logout Button (gated behind Parent Gate — UCD008)
          Positioned(
            bottom: 20,
            left: 20,
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => ParentGateDialog(
                    onSuccess: () => _confirmLogout(context, ref),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFFF6B6B), width: 3),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFFF6B6B),
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Big action button for Play, Draw, Stories
  Widget _buildBigActionButton({
    required String emoji,
    required String label,
    required List<Color> gradientColors,
    required Color shadowColor,
    required VoidCallback onTap,
  }) {
    const double size = 140; // Increased from 120
    const double emojiSize = 65; // Increased from 55
    const double fontSize = 26; // Increased from 24

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
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
                  blurRadius: 20,
                  offset: const Offset(0, 12),
                ),
              ],
              border: Border.all(color: Colors.white, width: 6),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: emojiSize)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          label,
          style: _cuteTextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            shadows: const [
              Shadow(
                  offset: Offset(2, 2), blurRadius: 6, color: Colors.black54),
            ],
          ),
        ),
      ],
    );
  }

  // Smaller action button for My Colors, Rewards
  Widget _buildSmallActionButton({
    required String emoji,
    required String label,
    required List<Color> gradientColors,
    required Color shadowColor,
    required VoidCallback onTap,
  }) {
    const double size = 120; // Increased from 100
    const double emojiSize = 55; // Increased from 48
    const double fontSize = 22; // Increased from 20

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
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
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(color: Colors.white, width: 5),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: emojiSize)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: _cuteTextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            shadows: const [
              Shadow(
                  offset: Offset(2, 2), blurRadius: 6, color: Colors.black54),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Log Out?',
            style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.fredoka(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child:
                Text('Cancel', style: GoogleFonts.fredoka(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(authProvider.notifier).signOut();
            },
            child: Text('Log Out',
                style: GoogleFonts.fredoka(color: Colors.white)),
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
