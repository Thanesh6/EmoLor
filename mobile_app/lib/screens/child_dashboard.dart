import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../core/widgets/parent_gate_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'draw_screen.dart';
import 'emoji_puzzle_screen.dart';
import 'emotion_bubbles_screen.dart';
import 'emoji_spelling_screen.dart';
import 'emo_match_screen.dart';
import 'emotion_slash_screen.dart';
import 'emotion_catcher_screen.dart';
import 'animal_sound_screen.dart';
import '../core/services/bg_music_player.dart';
import '../core/services/star_service.dart';
import '../features/child/services/child_rewards_service.dart';
import '../features/caregiver/services/goal_notification_service.dart';
import '../features/caregiver/services/goal_service.dart';

class ChildDashboard extends ConsumerStatefulWidget {
  final bool showSwitchAccount;
  final String? childName;
  final String avatarUrl;

  const ChildDashboard({
    super.key,
    this.showSwitchAccount = false,
    this.childName,
    this.avatarUrl = '',
  });

  @override
  ConsumerState<ChildDashboard> createState() => _ChildDashboardState();
}

class _ChildDashboardState extends ConsumerState<ChildDashboard>
    with SingleTickerProviderStateMixin {
  String? _resolvedChildName;
  String? _avatarEmoji;
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnim;
  late final Animation<Color?> _colorAnim;

  @override
  void initState() {
    super.initState();
    _resolvedChildName = widget.childName;
    // Use avatar passed from profile selection directly
    if (widget.avatarUrl.isNotEmpty) {
      _avatarEmoji = widget.avatarUrl;
    }
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
    BgMusicPlayer.instance.play();
    _startActiveTimeGoal();
  }

  Future<void> _startActiveTimeGoal() async {
    final goal = await GoalNotificationService.getActiveTimeGoal();
    if (goal == null || !mounted) return;
    GoalNotificationService.instance.startTimeGoal(
      context: context,
      targetMinutes: goal.target,
      goalId: goal.id,
      childName: _resolvedChildName ?? widget.childName,
      showSwitch: widget.showSwitchAccount,
    );
  }

  Future<void> _checkStarGoals() async {
    final starGoals = await GoalNotificationService.getActiveStarGoals();
    if (starGoals.isEmpty || !mounted) return;
    final currentStars = await StarService.getTotalStars();
    for (final goal in starGoals) {
      if (!mounted) return;
      await GoalNotificationService.instance.checkStarGoal(
        context: context,
        currentStars: currentStars,
        targetStars: goal.target,
        goalId: goal.id,
      );
    }
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

  Future<void> _openScreenAndRefresh(Widget screen,
      {bool checkStars = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (checkStars && mounted) {
      await _checkStarGoals();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    BgMusicPlayer.instance.stop();
    GoalNotificationService.instance.stopTimeGoal();
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

          // Switch button moved to bottom left corner

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
                        final titleText =
                            'WELCOME TO EMOLOR, ${(_resolvedChildName ?? 'CHILD').toUpperCase()}';
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

          // 8 Game Grid
          Positioned(
            top: 130,
            left: 16,
            right: 16,
            bottom: 100,
            child: GridView.count(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.25,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildGameBox(
                  emoji: '🧩',
                  label: 'EMOZZLE',
                  gradientColors: [
                    const Color(0xFFEF4444),
                    const Color(0xFFB91C1C)
                  ],
                  shadowColor: Colors.red,
                  onTap: () => _openScreenAndRefresh(const EmojiPuzzleScreen()),
                ),
                _buildGameBox(
                  emoji: '🫧',
                  label: 'EMOPOP',
                  gradientColors: [
                    const Color(0xFFA78BFA),
                    const Color(0xFF7C3AED)
                  ],
                  shadowColor: Colors.purple,
                  onTap: () =>
                      _openScreenAndRefresh(const EmotionBubblesScreen()),
                ),
                _buildGameBox(
                  emoji: '🔤',
                  label: 'EMOSPELL',
                  gradientColors: [
                    const Color.fromARGB(255, 240, 145, 219),
                    const Color.fromARGB(255, 252, 76, 222)
                  ],
                  shadowColor: Colors.pink,
                  onTap: () =>
                      _openScreenAndRefresh(const EmojiSpellingScreen()),
                ),
                _buildGameBox(
                  emoji: '🌟',
                  label: 'EMOMATCH',
                  gradientColors: [
                    const Color(0xFFF472B6),
                    const Color(0xFFDB2777)
                  ],
                  shadowColor: Colors.pink,
                  onTap: () => _openScreenAndRefresh(const EmoMatchScreen()),
                ),
                _buildGameBox(
                  emoji: '⚔️',
                  label: 'EMOSLASH',
                  gradientColors: [
                    const Color.fromARGB(255, 87, 202, 122),
                    const Color.fromARGB(255, 81, 201, 107)
                  ],
                  shadowColor: Colors.green,
                  onTap: () =>
                      _openScreenAndRefresh(const EmotionSlashScreen()),
                ),
                _buildGameBox(
                  emoji: '🧺',
                  label: 'EMOCATCH',
                  gradientColors: [
                    const Color(0xFF60A5FA),
                    const Color(0xFF2563EB)
                  ],
                  shadowColor: Colors.blue,
                  onTap: () =>
                      _openScreenAndRefresh(const EmotionCatcherScreen()),
                ),
                _buildGameBox(
                  emoji: '🐾',
                  label: 'ANIMATCH',
                  gradientColors: [
                    const Color(0xFFFBBF24),
                    const Color(0xFFD97706)
                  ],
                  shadowColor: Colors.amber,
                  onTap: () => _openScreenAndRefresh(const AnimalSoundScreen()),
                ),
                _buildGameBox(
                  emoji: '🖌️',
                  label: 'DRAW',
                  gradientColors: [
                    const Color(0xFF2DD4BF),
                    const Color(0xFF0D9488)
                  ],
                  shadowColor: Colors.teal,
                  onTap: () => _openScreenAndRefresh(const DrawScreen()),
                ),
              ],
            ),
          ),

          // Bottom Centre: Current reward display
          Positioned(
            bottom: 18,
            left: 0,
            right: 0,
            child: Center(
              child: FutureBuilder<List<ChildReward>>(
                future: ChildRewardsService.getAllRewards(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final unlocked = snapshot.data!
                      .where((r) => r.isUnlocked)
                      .toList()
                    ..sort((a, b) => b.unlockedAt!.compareTo(a.unlockedAt!));
                  if (unlocked.isEmpty) return const SizedBox.shrink();
                  final latest = unlocked.first;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                          width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(latest.emoji,
                            style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 8),
                        Text(
                          latest.title,
                          style: GoogleFonts.fredoka(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF6B21A8),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Bottom Left: Switch Profile (org only)
          if (widget.showSwitchAccount)
            Positioned(
              bottom: 18,
              left: 18,
              child: GestureDetector(
                onTap: () => _switchProfile(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.swap_horiz_rounded,
                          color: Colors.white, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Switch',
                        style: GoogleFonts.fredoka(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGameBox({
    required String emoji,
    required String label,
    required List<Color> gradientColors,
    required Color shadowColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.white, width: 3.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 70)),
            const SizedBox(height: 12),
            Text(
              label,
              style: _cuteTextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                shadows: const [
                  Shadow(
                    offset: Offset(1, 1),
                    blurRadius: 4,
                    color: Colors.black38,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switchProfile(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        titlePadding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
        contentPadding: const EdgeInsets.fromLTRB(32, 16, 32, 12),
        actionsPadding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
        title: Text(
          'Switch Profile?',
          style: GoogleFonts.fredoka(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to switch to a different profile?',
          style: GoogleFonts.fredoka(fontSize: 20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'No',
              style: GoogleFonts.fredoka(fontSize: 20, color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Proceed',
              style: GoogleFonts.fredoka(fontSize: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Profile switch mid-session — wipe per-session goals so the next
    // child starts with a clean slate.
    await GoalService.clearAll();
    GoalNotificationService.instance.resetAllStarAlerts();
    if (context.mounted) {
      context.go('/orgz-child-dashboard');
    }
  }

  // _confirmLogout removed — logout handled from profile selection page
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
