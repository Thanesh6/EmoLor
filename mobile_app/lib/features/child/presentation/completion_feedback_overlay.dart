import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/completion_record.dart';
import '../services/completion_service.dart';
import '../../../core/services/star_service.dart';
import '../../../features/caregiver/services/goal_notification_service.dart';
import '../services/activity_progress_service.dart';

/// UCD018 — reusable completion-feedback overlay.
///
/// Shows:
///  • confetti explosion + haptic buzz
///  • star-burst animation (reuses the existing StarRewardWidget approach)
///  • "Great Job!" title + score + stars earned
///  • "Play Again" and "Home" buttons
///
/// Automatically:
///  1. Awards stars via [StarService].
///  2. Persists a [CompletionRecord] via [CompletionService].
///  3. Clears any in-progress save via [ActivityProgressService].
///
/// Usage from a game screen:
/// ```dart
/// CompletionFeedbackOverlay.show(
///   context: context,
///   activityId: 'game_emotion_path',
///   activityName: 'Emotion Path',
///   starGameKey: StarService.emotionPath,
///   starsEarned: 2,
///   scoreValue: 4,
///   scoreMax: 5,
///   timeSpentSeconds: 120,
///   onPlayAgain: () { /* reset state */ },
/// );
/// ```
class CompletionFeedbackOverlay {
  CompletionFeedbackOverlay._();

  /// Show the completion screen as a full-screen modal route.
  static Future<void> show({
    required BuildContext context,
    required String activityId,
    required String activityName,
    required String starGameKey,
    required int starsEarned,
    int scoreValue = 0,
    int scoreMax = 0,
    int timeSpentSeconds = 0,
    VoidCallback? onPlayAgain,
  }) async {
    // 1. Award stars + immediately check star goals.
    await StarService.addStars(starGameKey, starsEarned);
    if (context.mounted) {
      await GoalNotificationService.instance.checkAllActiveStarGoals(
        context: context,
        deltaStars: starsEarned,
      );
    }

    // 2. Clear mid-game save (completed activities shouldn't show "resume").
    await ActivityProgressService().deleteProgress(activityId);

    // 3. Persist completion record (offline-first).
    await CompletionService.save(CompletionRecord(
      activityId: activityId,
      activityName: activityName,
      starsEarned: starsEarned,
      scoreValue: scoreValue,
      scoreMax: scoreMax,
      timeSpentSeconds: timeSpentSeconds,
      completedAt: DateTime.now(),
    ));

    // 4. Show the overlay.
    if (!context.mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (ctx, anim, __) => FadeTransition(
          opacity: anim,
          child: _FeedbackScreen(
            activityName: activityName,
            starsEarned: starsEarned,
            scoreValue: scoreValue,
            scoreMax: scoreMax,
            onPlayAgain: onPlayAgain,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  Private full-screen widget
// ──────────────────────────────────────────────────────────────

class _FeedbackScreen extends StatefulWidget {
  final String activityName;
  final int starsEarned;
  final int scoreValue;
  final int scoreMax;
  final VoidCallback? onPlayAgain;

  const _FeedbackScreen({
    required this.activityName,
    required this.starsEarned,
    this.scoreValue = 0,
    this.scoreMax = 0,
    this.onPlayAgain,
  });

  @override
  State<_FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<_FeedbackScreen>
    with TickerProviderStateMixin {
  late final ConfettiController _confetti;
  late final AnimationController _scaleCtrl;
  late final AnimationController _starCtrl;
  final List<_StarBurst> _bursts = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();

    // Confetti controller — 3 second burst.
    _confetti = ConfettiController(duration: const Duration(seconds: 3));

    // "Great Job" title scale-in.
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Star particle burst.
    _starCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    for (int i = 0; i < 16; i++) {
      _bursts.add(_StarBurst(
        angle: (i * 22.5) * (pi / 180),
        speed: 120 + _rng.nextDouble() * 100,
        size: 16 + _rng.nextDouble() * 18,
        color: _starColors[i % _starColors.length],
      ));
    }

    // Kick off the celebration 🎉
    _confetti.play();
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _scaleCtrl.forward();
      _starCtrl.forward();
      HapticFeedback.mediumImpact();
    });
  }

  static const _starColors = [
    Color(0xFFFFD700),
    Color(0xFFFFE66D),
    Color(0xFFFF9F43),
    Color(0xFFFF7EB3),
    Color(0xFF7ED957),
    Color(0xFF74B9FF),
  ];

  @override
  void dispose() {
    _confetti.dispose();
    _scaleCtrl.dispose();
    _starCtrl.dispose();
    super.dispose();
  }

  TextStyle _cute(
          {double sz = 24,
          Color c = Colors.white,
          FontWeight fw = FontWeight.w700}) =>
      GoogleFonts.baloo2(fontSize: sz, fontWeight: fw, color: c);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: Stack(
        children: [
          // ── Background gradient ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xCC6B21A8),
                  Color(0xCCEC4899),
                  Color(0xCCFF9F43),
                ],
              ),
            ),
          ),

          // ── Star-burst particles ──
          AnimatedBuilder(
            animation: _starCtrl,
            builder: (_, __) => CustomPaint(
              painter:
                  _BurstPainter(bursts: _bursts, progress: _starCtrl.value),
              size: Size.infinite,
            ),
          ),

          // ── Main content ──
          SafeArea(
            child: Center(
              child: ScaleTransition(
                scale: CurvedAnimation(
                    parent: _scaleCtrl, curve: Curves.elasticOut),
                child: _buildCard(),
              ),
            ),
          ),

          // ── Confetti ──
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 30,
              maxBlastForce: 30,
              minBlastForce: 10,
              emissionFrequency: 0.06,
              gravity: 0.2,
              colors: const [
                Color(0xFFFFD700),
                Color(0xFFFF6B6B),
                Color(0xFF7ED957),
                Color(0xFF74B9FF),
                Color(0xFFBB6BD9),
                Color(0xFFFF7EB3),
                Color(0xFFFF9F43),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text('Great Job!', style: _cute(sz: 36, c: const Color(0xFF6B21A8))),
          const SizedBox(height: 4),
          Text('Level Complete',
              style:
                  _cute(sz: 18, fw: FontWeight.w600, c: Colors.grey.shade500)),
          const SizedBox(height: 6),
          Text(widget.activityName,
              style:
                  _cute(sz: 16, fw: FontWeight.w500, c: Colors.grey.shade600)),
          const SizedBox(height: 20),

          // Stars row
          _buildStarsRow(),
          const SizedBox(height: 8),

          // Stars earned count
          Text(
            '${widget.starsEarned} / 3 Stars Earned',
            style: _cute(sz: 20, c: const Color(0xFFFFAA00)),
          ),
          const SizedBox(height: 20),

          // Buttons
          _buildButtons(),
        ],
      ),
    );
  }

  Widget _buildStarsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final earned = i < widget.starsEarned;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(
            earned ? Icons.star_rounded : Icons.star_border_rounded,
            size: 48,
            color: earned ? const Color(0xFFFFD700) : Colors.grey.shade300,
          ),
        );
      }),
    );
  }

  Widget _buildButtons() {
    return Column(
      children: [
        // Play Again
        if (widget.onPlayAgain != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); // dismiss overlay
                widget.onPlayAgain!();
              },
              icon: const Icon(Icons.replay_rounded, size: 24),
              label: Text('Play Again', style: _cute(sz: 20)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7ED957),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),
        if (widget.onPlayAgain != null) const SizedBox(height: 12),

        // Home
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context); // dismiss overlay
              Navigator.pop(context); // pop game screen → browse / map
            },
            icon: const Icon(Icons.home_rounded, size: 24),
            label:
                Text('Home', style: _cute(sz: 20, c: const Color(0xFF6B21A8))),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6B21A8),
              side: const BorderSide(color: Color(0xFF6B21A8), width: 2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  Star-burst particle system (lightweight CustomPainter)
// ──────────────────────────────────────────────────────────────

class _StarBurst {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  const _StarBurst({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
  });
}

class _BurstPainter extends CustomPainter {
  final List<_StarBurst> bursts;
  final double progress;
  _BurstPainter({required this.bursts, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    for (final b in bursts) {
      final dist = b.speed * progress;
      final x = cx + cos(b.angle) * dist;
      final y = cy + sin(b.angle) * dist;
      final s = b.size * (1.0 - progress * 0.5);
      _drawStar(canvas, x, y, s, b.color.withValues(alpha: opacity));
    }
  }

  void _drawStar(Canvas canvas, double x, double y, double r, Color color) {
    final paint = Paint()..color = color;
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final a = (i * 72 - 90) * pi / 180;
      final ix = x + r * cos(a);
      final iy = y + r * sin(a);
      if (i == 0) {
        path.moveTo(ix, iy);
      } else {
        path.lineTo(ix, iy);
      }
      final ia = ((i * 72) + 36 - 90) * pi / 180;
      path.lineTo(x + r * 0.4 * cos(ia), y + r * 0.4 * sin(ia));
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.progress != progress;
}
