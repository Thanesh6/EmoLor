import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/data/game_emojis.dart';
import '../core/logic/adaptive_engine.dart';
import '../features/child/presentation/help_button.dart';
import '../features/child/presentation/activity_exit_handler.dart';
import '../features/child/presentation/completion_feedback_overlay.dart';
import '../core/services/star_service.dart';
import '../features/child/services/activity_progress_service.dart';

/// Emotion Slash — Fruit-Ninja-style game where emotion faces fly across
/// the screen and the child swipes to slash the ones matching the target.
class EmotionSlashScreen extends StatefulWidget {
  const EmotionSlashScreen({super.key});

  @override
  State<EmotionSlashScreen> createState() => _EmotionSlashScreenState();
}

class _FlyingEmoji {
  final String emoji;
  final String emotionName;
  final Color color;
  final bool isTarget;
  double x;
  double y;
  double vx;
  double vy;
  bool slashed = false;
  double slashOpacity = 1.0;

  _FlyingEmoji({
    required this.emoji,
    required this.emotionName,
    required this.color,
    required this.isTarget,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
  });
}

class _SlashTrail {
  final List<Offset> points;
  double opacity;
  _SlashTrail({required this.points, this.opacity = 1.0});
}

class _Particle {
  double x, y, vx, vy, life, size;
  Color color;
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    this.life = 1.0,
    this.size = 6.0,
  });
}

class _EmotionSlashScreenState extends State<EmotionSlashScreen>
    with TickerProviderStateMixin {
  static const String _activityId = 'game_emotion_slash';
  static const int _maxRounds = 10;
  static const double _gravity = 0.18;

  final ActivityProgressService _progressService = ActivityProgressService();
  final Random _rng = Random();
  final AdaptiveEngine _engine = AdaptiveEngine(
    frustrationThreshold: 3,
    overloadTapsPerSecond: 6.0,
  );

  // All 48 emojis from shared data
  late final List<Map<String, dynamic>> _emotions =
      GameEmojis.all.map((e) => e.toMap()).toList();

  // Shuffled order to ensure all 48 get cycled through as targets
  late List<int> _targetOrder;
  int _targetIndex = 0;

  late Map<String, dynamic> _targetEmotion;
  final List<_FlyingEmoji> _emojis = [];
  final List<_SlashTrail> _trails = [];
  final List<_Particle> _particles = [];
  List<Offset> _currentSlash = [];
  bool _isDragging = false;

  Timer? _gameTicker;
  Timer? _spawnTimer;
  Timer? _roundTimer;

  int _round = 0;
  int _lives = 3;
  int _score = 0;
  int _totalMistakes = 0;
  int _roundScore = 0;
  bool _betweenRounds = false;
  bool _gameEnded = false;

  late AnimationController _flashController;
  late AnimationController _roundTransitionController;

  double _screenW = 800;
  double _screenH = 600;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _roundTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _targetOrder = List.generate(_emotions.length, (i) => i)..shuffle(_rng);
    _targetIndex = 0;
    _targetEmotion = _emotions[_targetOrder[0]];
    _gameTicker =
        Timer.periodic(const Duration(milliseconds: 30), (_) => _tick());
    _restoreProgress();
  }

  Future<void> _restoreProgress() async {
    final saved = await _progressService.loadProgress(_activityId);
    if (!mounted || saved == null) return;
    final data = saved.progressData;
    if (data['round'] is int && data['score'] is int && data['lives'] is int) {
      setState(() {
        _round = (data['round'] as int).clamp(0, _maxRounds - 1);
        _score = data['score'] as int;
        _lives = (data['lives'] as int).clamp(1, 3);
        _totalMistakes = (data['totalMistakes'] as int?) ?? 0;
      });
    }
    // Start the round after a brief delay for layout
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _startRound();
    });
  }

  Map<String, dynamic> _buildProgressData() => {
        'round': _round,
        'score': _score,
        'lives': _lives,
        'totalMistakes': _totalMistakes,
      };

  @override
  void dispose() {
    _gameTicker?.cancel();
    _spawnTimer?.cancel();
    _roundTimer?.cancel();
    _flashController.dispose();
    _roundTransitionController.dispose();
    super.dispose();
  }

  // ── Round Management ─────────────────────────────────────────────

  void _startRound() {
    if (_gameEnded) return;
    _emojis.clear();
    _roundScore = 0;
    _targetEmotion = _emotions[_targetOrder[_targetIndex % _emotions.length]];
    _targetIndex++;

    setState(() => _betweenRounds = true);
    _roundTransitionController.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted || _gameEnded) return;
      setState(() => _betweenRounds = false);

      // Spawn emojis at intervals
      final spawnInterval =
          Duration(milliseconds: (1500 - _round * 60).clamp(800, 1500));
      int spawned = 0;
      final maxSpawn = 8 + (_round ~/ 3); // 8-11 emojis per round

      _spawnTimer = Timer.periodic(spawnInterval, (timer) {
        if (!mounted || _gameEnded || _betweenRounds) {
          timer.cancel();
          return;
        }
        if (spawned >= maxSpawn) {
          timer.cancel();
          return;
        }
        _spawnEmoji();
        spawned++;
      });

      // Round ends after time limit
      final roundDuration = Duration(seconds: (15 + _round).clamp(15, 20));
      _roundTimer?.cancel();
      _roundTimer = Timer(roundDuration, () {
        if (mounted && !_gameEnded) _endRound();
      });
    });
  }

  void _spawnEmoji() {
    if (_gameEnded) return;
    final velocityScale = 1.0 + _round * 0.07;
    final isTarget = _rng.nextDouble() < 0.4; // 40% chance target
    final emotion = isTarget
        ? _targetEmotion
        : _emotions
            .where((e) => e['name'] != _targetEmotion['name'])
            .toList()[_rng.nextInt(_emotions.length - 1)];

    // Launch from bottom with upward arc
    final startX = 80 + _rng.nextDouble() * (_screenW - 160);
    final startY = _screenH + 40;
    final vx = (_rng.nextDouble() - 0.5) * 3.0 * velocityScale;
    final vy = -(11.0 + _rng.nextDouble() * 5.0) * velocityScale;

    _emojis.add(_FlyingEmoji(
      emoji: emotion['emoji'] as String,
      emotionName: emotion['name'] as String,
      color: emotion['color'] as Color,
      isTarget: isTarget,
      x: startX,
      y: startY,
      vx: vx,
      vy: vy,
    ));
  }

  void _endRound() {
    _spawnTimer?.cancel();
    _roundTimer?.cancel();

    if (_lives <= 0 || _round + 1 >= _maxRounds) {
      _endGame();
    } else {
      _round++;
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && !_gameEnded) _startRound();
      });
    }
  }

  void _endGame() {
    _gameEnded = true;
    _gameTicker?.cancel();
    _spawnTimer?.cancel();
    _roundTimer?.cancel();

    int stars;
    if (_totalMistakes == 0) {
      stars = 3;
    } else if (_totalMistakes <= 2) {
      stars = 2;
    } else {
      stars = 1;
    }

    CompletionFeedbackOverlay.show(
      context: context,
      activityId: _activityId,
      activityName: 'Emotion Slash',
      starGameKey: StarService.emotionPath,
      starsEarned: stars,
      scoreValue: _score,
      scoreMax: _maxRounds * 4,
      onPlayAgain: _restart,
    );
  }

  void _restart() {
    _engine.reset();
    _targetOrder = List.generate(_emotions.length, (i) => i)..shuffle(_rng);
    _targetIndex = 0;
    setState(() {
      _round = 0;
      _lives = 3;
      _score = 0;
      _totalMistakes = 0;
      _gameEnded = false;
      _betweenRounds = false;
      _emojis.clear();
      _trails.clear();
      _particles.clear();
    });
    _gameTicker =
        Timer.periodic(const Duration(milliseconds: 30), (_) => _tick());
    _startRound();
  }

  // ── Game Loop ────────────────────────────────────────────────────

  void _tick() {
    if (_gameEnded || _betweenRounds) return;
    setState(() {
      // Update emoji positions
      for (final e in _emojis) {
        if (e.slashed) {
          e.slashOpacity -= 0.08;
          continue;
        }
        e.x += e.vx;
        e.y += e.vy;
        e.vy += _gravity;
      }
      // Remove off-screen or faded emojis
      _emojis.removeWhere((e) =>
          e.y > _screenH + 80 ||
          e.x < -80 ||
          e.x > _screenW + 80 ||
          e.slashOpacity <= 0);

      // Update particles
      for (final p in _particles) {
        p.x += p.vx;
        p.y += p.vy;
        p.vy += 0.1;
        p.life -= 0.03;
      }
      _particles.removeWhere((p) => p.life <= 0);

      // Fade slash trails
      for (final t in _trails) {
        t.opacity -= 0.06;
      }
      _trails.removeWhere((t) => t.opacity <= 0);
    });
  }

  // ── Gesture Handling ─────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent event) {
    _isDragging = true;
    _currentSlash = [event.localPosition];
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_isDragging) return;
    _currentSlash.add(event.localPosition);
    _checkSlashCollisions();
  }

  void _onPointerUp(PointerUpEvent event) {
    _isDragging = false;
    if (_currentSlash.length > 2) {
      _trails.add(_SlashTrail(points: List.from(_currentSlash)));
    }
    _currentSlash = [];
  }

  void _checkSlashCollisions() {
    if (_currentSlash.length < 2) return;
    final p1 = _currentSlash[_currentSlash.length - 2];
    final p2 = _currentSlash.last;

    for (final emoji in _emojis) {
      if (emoji.slashed) continue;
      final center = Offset(emoji.x, emoji.y);
      const hitRadius = 42.0;

      if (_lineCircleIntersect(p1, p2, center, hitRadius)) {
        _onEmojiSlashed(emoji);
      }
    }
  }

  bool _lineCircleIntersect(Offset a, Offset b, Offset center, double radius) {
    final d = b - a;
    final f = a - center;
    final a2 = d.dx * d.dx + d.dy * d.dy;
    if (a2 < 0.001) return false;
    final b2 = 2 * (f.dx * d.dx + f.dy * d.dy);
    final c2 = f.dx * f.dx + f.dy * f.dy - radius * radius;
    var discriminant = b2 * b2 - 4 * a2 * c2;
    if (discriminant < 0) return false;
    discriminant = sqrt(discriminant);
    final t1 = (-b2 - discriminant) / (2 * a2);
    final t2 = (-b2 + discriminant) / (2 * a2);
    return (t1 >= 0 && t1 <= 1) || (t2 >= 0 && t2 <= 1);
  }

  void _onEmojiSlashed(_FlyingEmoji emoji) {
    emoji.slashed = true;
    _engine.recordTap();

    if (emoji.isTarget) {
      _score++;
      _roundScore++;
      _engine.resetErrors();
      _spawnExplosion(emoji.x, emoji.y, emoji.color);
    } else {
      _totalMistakes++;
      _lives--;
      _engine.trackError();
      _flashController.forward(from: 0);
      if (_lives <= 0) {
        _endRound();
      }
    }
  }

  void _spawnExplosion(double x, double y, Color color) {
    for (int i = 0; i < 14; i++) {
      final angle = (i / 14) * 2 * pi;
      _particles.add(_Particle(
        x: x,
        y: y,
        vx: cos(angle) * (3 + _rng.nextDouble() * 5),
        vy: sin(angle) * (3 + _rng.nextDouble() * 5),
        color: color,
        life: 1.0,
        size: 5 + _rng.nextDouble() * 8,
      ));
    }
  }

  // ── Exit Handler ─────────────────────────────────────────────────

  Future<void> _handleReturnPressed() async {
    _gameTicker?.cancel();
    _spawnTimer?.cancel();
    _roundTimer?.cancel();
    await ActivityExitHandler.handleExitActivity(
      context: context,
      activityId: _activityId,
      activityEmoji: '⚔️',
      buildProgressData: _buildProgressData,
    );
    if (mounted && !_gameEnded) {
      _gameTicker =
          Timer.periodic(const Duration(milliseconds: 30), (_) => _tick());
      _startRound();
    }
  }

  TextStyle _cute({
    double size = 24,
    FontWeight weight = FontWeight.w700,
    Color color = Colors.white,
  }) {
    return GoogleFonts.baloo2(fontSize: size, fontWeight: weight, color: color);
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _screenW = MediaQuery.of(context).size.width;
    _screenH = MediaQuery.of(context).size.height;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _handleReturnPressed();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE8DEF8), Color(0xFFD0BCFF), Color(0xFFB8C0E8)],
            ),
          ),
          child: SafeArea(
            child: Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              behavior: HitTestBehavior.opaque,
              child: Stack(
                children: [
                  // Slash trails + particles
                  if (_trails.isNotEmpty ||
                      _currentSlash.length >= 2 ||
                      _particles.isNotEmpty)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _SlashPainter(
                            trails: _trails,
                            currentSlash: _currentSlash,
                            particles: _particles,
                          ),
                        ),
                      ),
                    ),

                  // Flying emojis (20% bigger)
                  ..._emojis
                      .where((e) => !e.slashed || e.slashOpacity > 0)
                      .map((e) {
                    return Positioned(
                      left: e.x - 36,
                      top: e.y - 36,
                      child: Opacity(
                        opacity:
                            e.slashed ? e.slashOpacity.clamp(0.0, 1.0) : 1.0,
                        child: Transform.scale(
                          scale: e.slashed ? 1.5 : 1.0,
                          child: Text(
                            e.emoji,
                            style: const TextStyle(fontSize: 72),
                          ),
                        ),
                      ),
                    );
                  }),

                  // Target prompt bar (20% bigger) + level display
                  Positioned(
                    top: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 17, horizontal: 34),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: (_targetEmotion['color'] as Color)
                                .withValues(alpha: 0.8),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_targetEmotion['color'] as Color)
                                  .withValues(alpha: 0.4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Slash: ',
                                style: _cute(size: 26, color: Colors.black87)),
                            Text(_targetEmotion['emoji'] as String,
                                style: const TextStyle(fontSize: 46)),
                            const SizedBox(width: 10),
                            Text(
                              _targetEmotion['name'] as String,
                              style: _cute(
                                size: 34,
                                weight: FontWeight.w900,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text('${_round + 1}/$_maxRounds',
                                  style:
                                      _cute(size: 22, color: Colors.black54)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Lives (hearts) — bottom right
                  Positioned(
                    bottom: 24,
                    right: 20,
                    child: Row(
                      children: List.generate(3, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            i < _lives ? Icons.favorite : Icons.favorite_border,
                            color: i < _lives
                                ? const Color(0xFFFF6B6B)
                                : Colors.black26,
                            size: 45,
                          ),
                        );
                      }),
                    ),
                  ),

                  // Hint + Star — top right (matched to Emoji Puzzle)
                  Positioned(
                    top: 14,
                    right: 16,
                    child: Row(
                      children: [
                        HelpButton(
                          activityId: 'game_emotion_slash',
                          activityEmoji: '⚔️',
                          activityName: 'Emotion Slash',
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 19, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B21A8),
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: Text('⭐ $_score', style: _cute(size: 26)),
                        ),
                      ],
                    ),
                  ),

                  // Back button
                  Positioned(
                    top: 20,
                    left: 20,
                    child: GestureDetector(
                      onTap: _handleReturnPressed,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4)),
                          ],
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: Color(0xFF6B21A8), size: 30),
                      ),
                    ),
                  ),

                  // Red flash overlay on wrong slash
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _flashController,
                        builder: (context, child) {
                          final opacity = (1.0 - _flashController.value) * 0.35;
                          if (opacity <= 0) return const SizedBox.shrink();
                          return Container(
                            color: Colors.red.withValues(alpha: opacity),
                          );
                        },
                      ),
                    ),
                  ),

                  // Round transition overlay
                  if (_betweenRounds)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _roundTransitionController,
                          builder: (context, child) {
                            final scale =
                                0.5 + _roundTransitionController.value * 0.5;
                            final opacity = _roundTransitionController.value <
                                    0.8
                                ? 1.0
                                : 1.0 -
                                    (_roundTransitionController.value - 0.8) *
                                        5;
                            return Opacity(
                              opacity: opacity.clamp(0.0, 1.0),
                              child: Center(
                                child: Transform.scale(
                                  scale: scale,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Round ${_round + 1}',
                                        style: _cute(
                                          size: 52,
                                          weight: FontWeight.w900,
                                          color: const Color(0xFF1F2937),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('Slash the ',
                                              style: _cute(
                                                  size: 30,
                                                  color:
                                                      const Color(0xFF1F2937))),
                                          Text(
                                            '${_targetEmotion['emoji']} ${_targetEmotion['name']}',
                                            style: _cute(
                                              size: 34,
                                              weight: FontWeight.w900,
                                              color: _targetEmotion['color']
                                                  as Color,
                                            ),
                                          ),
                                          Text(' faces!',
                                              style: _cute(
                                                  size: 30,
                                                  color:
                                                      const Color(0xFF1F2937))),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Custom Painter for slash trails and particles ───────────────────

class _SlashPainter extends CustomPainter {
  final List<_SlashTrail> trails;
  final List<Offset> currentSlash;
  final List<_Particle> particles;

  _SlashPainter({
    required this.trails,
    required this.currentSlash,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw fading trails
    for (final trail in trails) {
      if (trail.points.length < 2) continue;
      final paint = Paint()
        ..color = Colors.white
            .withValues(alpha: (trail.opacity * 0.8).clamp(0.0, 1.0))
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(trail.points.first.dx, trail.points.first.dy);
      for (int i = 1; i < trail.points.length; i++) {
        path.lineTo(trail.points[i].dx, trail.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    // Draw current active slash
    if (currentSlash.length >= 2) {
      final glowPaint = Paint()
        ..color = const Color(0xFFFFE066).withValues(alpha: 0.5)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      final slashPaint = Paint()
        ..color = const Color(0xFFFFE066)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final path = Path()..moveTo(currentSlash.first.dx, currentSlash.first.dy);
      for (int i = 1; i < currentSlash.length; i++) {
        path.lineTo(currentSlash[i].dx, currentSlash[i].dy);
      }
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, slashPaint);
    }

    // Draw particles
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.life.clamp(0.0, 1.0));
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.size * p.life.clamp(0.0, 1.0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SlashPainter oldDelegate) {
    return trails.isNotEmpty ||
        currentSlash.length >= 2 ||
        particles.isNotEmpty;
  }
}
