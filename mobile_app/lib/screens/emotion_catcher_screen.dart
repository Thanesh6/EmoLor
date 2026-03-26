import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/data/game_emojis.dart';
import '../core/services/star_service.dart';
import '../core/widgets/star_reward_widget.dart';
import '../core/logic/adaptive_engine.dart';
import '../features/child/presentation/help_button.dart';
import '../features/child/presentation/activity_exit_handler.dart';
import '../features/child/services/activity_progress_service.dart';
import '../core/services/emotion_journal_service.dart';

/// Emotion Catcher — Emojis rain from the sky and the child moves a basket
/// left/right to catch the ones matching the target emotion.
class EmotionCatcherScreen extends StatefulWidget {
  const EmotionCatcherScreen({super.key});

  @override
  State<EmotionCatcherScreen> createState() => _EmotionCatcherScreenState();
}

class _FallingEmoji {
  final String emoji;
  final String emotionName;
  final Color color;
  final bool isTarget;
  double x; // center x in pixels
  double y; // center y in pixels
  double speed; // pixels per tick (downward)
  bool caught = false;
  bool missed = false;
  double catchScale = 1.0; // shrinks on catch

  _FallingEmoji({
    required this.emoji,
    required this.emotionName,
    required this.color,
    required this.isTarget,
    required this.x,
    required this.y,
    required this.speed,
  });
}

class _Sparkle {
  double x, y, vx, vy, life, size;
  Color color;
  _Sparkle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    this.life = 1.0,
    this.size = 5.0,
  });
}

class _EmotionCatcherScreenState extends State<EmotionCatcherScreen>
    with TickerProviderStateMixin {
  static const String _activityId = 'game_emotion_catcher';
  static const double _basketWidth = 156.0;
  static const double _basketHeight = 84.0;

  final ActivityProgressService _progressService = ActivityProgressService();
  final Random _rng = Random();
  final AdaptiveEngine _engine = AdaptiveEngine(
    frustrationThreshold: 3,
    overloadTapsPerSecond: 6.0,
  );

  // All 48 emojis from shared data
  late final List<Map<String, dynamic>> _emotions =
      GameEmojis.all.map((e) => e.toMap()).toList();

  /// Builds target order: feelings indices first (shuffled), then rest (shuffled).
  List<int> _buildFeelingsFirstOrder() {
    final feelingsIdx = <int>[];
    final restIdx = <int>[];
    for (int i = 0; i < _emotions.length; i++) {
      if (_emotions[i]['category'] == 'feelings') {
        feelingsIdx.add(i);
      } else {
        restIdx.add(i);
      }
    }
    feelingsIdx.shuffle(_rng);
    restIdx.shuffle(_rng);
    return [...feelingsIdx, ...restIdx];
  }

  // Shuffled order to ensure all 48 get cycled through as targets
  late List<int> _targetOrder;
  int _targetIndex = 0;

  late Map<String, dynamic> _targetEmotion;
  final List<_FallingEmoji> _fallingEmojis = [];
  final List<_Sparkle> _sparkles = [];

  Timer? _gameTicker;
  Timer? _spawnTimer;

  double _basketX = 0.5; // fraction of screen width
  int _sessionStars = 0;
  int _lives = 3;
  int _levelErrors = 0; // errors for current target
  bool _betweenRounds = false;
  bool _gameEnded = false;

  late AnimationController _shakeController;
  late AnimationController _roundTransitionController;

  double _screenW = 800;
  double _screenH = 600;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _roundTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _targetOrder = _buildFeelingsFirstOrder();
    _targetIndex = 0;
    _targetEmotion = _emotions[_targetOrder[0]];
    _gameTicker =
        Timer.periodic(const Duration(milliseconds: 30), (_) => _tick());
    _restoreProgress();
  }

  Future<void> _restoreProgress() async {
    final saved = await _progressService.loadProgress(_activityId);
    if (!mounted) return;
    if (saved != null) {
      final data = saved.progressData;
      final savedOrder = data['targetOrder'];
      final savedIndex = data['targetIndex'];
      final savedLives = data['lives'];
      if (savedOrder is List && savedIndex is int && savedLives is int) {
        final order = savedOrder.whereType<num>().map((n) => n.toInt()).toList();
        if (order.isNotEmpty && order.every((i) => i >= 0 && i < _emotions.length)) {
          _targetOrder = order;
          _targetIndex = savedIndex.clamp(0, order.length);
          _lives = savedLives.clamp(1, 3);
        }
      }
    }
    _sessionStars = 0;
    _targetEmotion = _emotions[_targetOrder[_targetIndex % _emotions.length]];
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _showTarget();
    });
  }

  Map<String, dynamic> _buildProgressData() => {
        'targetOrder': _targetOrder,
        'targetIndex': _targetIndex,
        'lives': _lives,
      };

  @override
  void dispose() {
    _gameTicker?.cancel();
    _spawnTimer?.cancel();
    _shakeController.dispose();
    _roundTransitionController.dispose();
    super.dispose();
  }

  // ── Target Management ─────────────────────────────────────────────

  void _showTarget() {
    if (_gameEnded) return;
    _fallingEmojis.clear();
    _targetEmotion = _emotions[_targetOrder[_targetIndex % _emotions.length]];
    _levelErrors = 0;

    setState(() => _betweenRounds = true);
    _roundTransitionController.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted || _gameEnded) return;
      setState(() => _betweenRounds = false);
      _startSpawning();
    });
  }

  void _startSpawning() {
    _spawnTimer?.cancel();
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 1400), (timer) {
      if (!mounted || _gameEnded || _betweenRounds) {
        timer.cancel();
        return;
      }
      _spawnEmoji();
    });
    // Spawn one immediately
    _spawnEmoji();
  }

  void _advanceTarget() {
    _spawnTimer?.cancel();
    _targetIndex++;
    // When all 48 emojis have been shown, reshuffle and start over
    if (_targetIndex >= _emotions.length) {
      _targetOrder = _buildFeelingsFirstOrder();
      _targetIndex = 0;
    }
    _sessionStars++;
    EmotionJournalService.log(
      emoji: _targetEmotion['emoji'] as String,
      emotionName: _targetEmotion['name'] as String,
      category: _targetEmotion['category'] as String,
      gameId: _activityId,
    );
    StarRewardWidget.show(context);

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && !_gameEnded) _showTarget();
    });
  }

  void _spawnEmoji() {
    if (_gameEnded) return;
    // Adaptive: increase target chance and slow fall speed on errors
    final targetChance = _levelErrors == 0
        ? 0.35
        : _levelErrors == 1
            ? 0.5
            : 0.65; // 2+ errors: 65% target
    final fallSpeed = _levelErrors >= 2
        ? 1.5
        : _levelErrors == 1
            ? 2.0
            : 2.5;
    final isTarget = _rng.nextDouble() < targetChance;
    final emotion = isTarget
        ? _targetEmotion
        : _emotions
            .where((e) => e['name'] != _targetEmotion['name'])
            .toList()[_rng.nextInt(_emotions.length - 1)];

    final startX = 50 + _rng.nextDouble() * (_screenW - 100);

    _fallingEmojis.add(_FallingEmoji(
      emoji: emotion['emoji'] as String,
      emotionName: emotion['name'] as String,
      color: emotion['color'] as Color,
      isTarget: isTarget,
      x: startX,
      y: -50,
      speed: fallSpeed + _rng.nextDouble() * 1.0,
    ));
  }

  void _restart() {
    _engine.reset();
    _targetOrder = _buildFeelingsFirstOrder();
    _targetIndex = 0;
    setState(() {
      _sessionStars = 0;
      _lives = 3;
      _gameEnded = false;
      _betweenRounds = false;
      _basketX = 0.5;
      _fallingEmojis.clear();
      _sparkles.clear();
    });
    _gameTicker =
        Timer.periodic(const Duration(milliseconds: 30), (_) => _tick());
    _showTarget();
  }

  // ── Game Loop ────────────────────────────────────────────────────

  void _tick() {
    if (_gameEnded || _betweenRounds) return;
    setState(() {
      final basketLeft = _basketX * _screenW - _basketWidth / 2;
      final basketRight = basketLeft + _basketWidth;
      final basketTop = _screenH - 30 - _basketHeight;

      for (final e in _fallingEmojis) {
        if (e.caught) {
          e.catchScale -= 0.1;
          continue;
        }
        if (e.missed) continue;
        e.y += e.speed;

        // Check basket collision
        if (e.y + 42 >= basketTop &&
            e.y - 42 <= _screenH - 30 &&
            e.x + 42 >= basketLeft &&
            e.x - 42 <= basketRight) {
          _onEmojiCaught(e);
        }

        // Missed (fell past screen)
        if (e.y > _screenH + 60) {
          e.missed = true;
        }
      }

      // Remove fully faded caught emojis and missed ones
      _fallingEmojis
          .removeWhere((e) => e.missed || (e.caught && e.catchScale <= 0));

      // Update sparkles
      for (final s in _sparkles) {
        s.x += s.vx;
        s.y += s.vy;
        s.vy += 0.08;
        s.life -= 0.025;
      }
      _sparkles.removeWhere((s) => s.life <= 0);
    });
  }

  void _onEmojiCaught(_FallingEmoji emoji) {
    emoji.caught = true;
    _engine.recordTap();

    if (emoji.isTarget) {
      _engine.resetErrors();
      _spawnSparkles(emoji.x, emoji.y, emoji.color);
      // Correct catch — advance to next target
      _advanceTarget();
    } else {
      _lives--;
      _levelErrors++;
      _engine.trackError();
      _shakeController.forward(from: 0);
      if (_lives <= 0) {
        // Reset lives, keep going
        _lives = 3;
      }
    }
  }

  void _spawnSparkles(double x, double y, Color color) {
    for (int i = 0; i < 10; i++) {
      final angle = (i / 10) * 2 * pi;
      _sparkles.add(_Sparkle(
        x: x,
        y: y,
        vx: cos(angle) * (2 + _rng.nextDouble() * 3),
        vy: sin(angle) * (2 + _rng.nextDouble() * 3) - 2,
        color: Color.lerp(color, Colors.yellow, 0.5)!,
        life: 1.0,
        size: 4 + _rng.nextDouble() * 6,
      ));
    }
  }

  // ── Exit Handler ─────────────────────────────────────────────────

  Future<void> _handleReturnPressed() async {
    _gameTicker?.cancel();
    _spawnTimer?.cancel();
    await ActivityExitHandler.handleExitActivity(
      context: context,
      activityId: _activityId,
      activityName: 'EMOCATCH',
      activityEmoji: '🧺',
      buildProgressData: _buildProgressData,
      starGameKey: StarService.emotionCatcher,
      sessionStars: _sessionStars,
    );
    if (mounted && !_gameEnded) {
      _gameTicker =
          Timer.periodic(const Duration(milliseconds: 30), (_) => _tick());
      _showTarget();
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
              colors: [
                Color(0xFF87CEEB), // Sky blue
                Color(0xFF98D8C8), // Soft teal
                Color(0xFF7BC67E), // Grass green
              ],
            ),
          ),
          child: SafeArea(
            child: Listener(
              onPointerMove: (event) {
                setState(() {
                  _basketX = (event.localPosition.dx / _screenW).clamp(
                    _basketWidth / 2 / _screenW,
                    1.0 - _basketWidth / 2 / _screenW,
                  );
                });
              },
              behavior: HitTestBehavior.opaque,
              child: Stack(
                children: [
                  // Sparkle particles
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SparklePainter(sparkles: _sparkles),
                    ),
                  ),

                  // Clouds (decorative)
                  ..._buildClouds(),

                  // Falling emojis
                  ..._fallingEmojis
                      .where((e) => !e.missed && e.catchScale > 0)
                      .map((e) {
                    // Adaptive hint: glow around target emojis on 2+ errors
                    final showHint = !e.caught && e.isTarget && _levelErrors >= 2;
                    return Positioned(
                      left: e.x - 36,
                      top: e.y - 36,
                      child: Transform.scale(
                        scale: e.caught ? e.catchScale.clamp(0.0, 1.0) : 1.0,
                        child: Container(
                          decoration: showHint
                              ? BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF4CAF50)
                                          .withValues(alpha: 0.6),
                                      blurRadius: 20,
                                      spreadRadius: 8,
                                    ),
                                  ],
                                )
                              : null,
                          child: Text(e.emoji,
                              style: const TextStyle(fontSize: 72)),
                        ),
                      ),
                    );
                  }),

                  // Basket
                  Positioned(
                    left: _basketX * _screenW - _basketWidth / 2,
                    bottom: 30,
                    child: AnimatedBuilder(
                      animation: _shakeController,
                      builder: (_, child) {
                        final shakeOffset = _shakeController.isAnimating
                            ? sin(_shakeController.value * pi * 4) * 8
                            : 0.0;
                        return Transform.translate(
                          offset: Offset(shakeOffset, 0),
                          child: child,
                        );
                      },
                      child: _buildBasket(),
                    ),
                  ),

                  // Target prompt bar
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
                                  .withValues(alpha: 0.3),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Catch: ',
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
                                : Colors.white38,
                            size: 45,
                          ),
                        );
                      }),
                    ),
                  ),

                  // Hint + Star — top right
                  Positioned(
                    top: 14,
                    right: 16,
                    child: Row(
                      children: [
                        HelpButton(
                          activityId: 'game_emotion_catcher',
                          activityEmoji: '🧺',
                          activityName: 'EMOCATCH',
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 19, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B21A8),
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: Text('⭐ $_sessionStars', style: _cute(size: 26)),
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
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: Color(0xFF6B21A8), size: 30),
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
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.3),
                                child: Center(
                                  child: Transform.scale(
                                    scale: scale,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('Catch the ',
                                                style: _cute(size: 30)),
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
                                                style: _cute(size: 30)),
                                          ],
                                        ),
                                      ],
                                    ),
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

  Widget _buildBasket() {
    return Container(
      width: _basketWidth,
      height: _basketHeight,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD2691E), Color(0xFF8B4513)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
        border: Border.all(color: const Color(0xFF5C3317), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🧺', style: TextStyle(fontSize: 32)),
          Text('CATCH!',
              style: _cute(
                  size: 12, weight: FontWeight.w800, color: Colors.white)),
        ],
      ),
    );
  }

  List<Widget> _buildClouds() {
    return [
      Positioned(
        top: 120,
        left: _screenW * 0.1,
        child: Opacity(
          opacity: 0.4,
          child: Text('☁️', style: TextStyle(fontSize: 60)),
        ),
      ),
      Positioned(
        top: 80,
        right: _screenW * 0.15,
        child: Opacity(
          opacity: 0.3,
          child: Text('☁️', style: TextStyle(fontSize: 80)),
        ),
      ),
      Positioned(
        top: 180,
        left: _screenW * 0.5,
        child: Opacity(
          opacity: 0.25,
          child: Text('☁️', style: TextStyle(fontSize: 50)),
        ),
      ),
    ];
  }
}

// ── Custom Painter for sparkle particles ────────────────────────────

class _SparklePainter extends CustomPainter {
  final List<_Sparkle> sparkles;

  _SparklePainter({required this.sparkles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in sparkles) {
      final paint = Paint()
        ..color = s.color.withValues(alpha: s.life.clamp(0.0, 1.0));
      canvas.drawCircle(
        Offset(s.x, s.y),
        s.size * s.life.clamp(0.0, 1.0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
