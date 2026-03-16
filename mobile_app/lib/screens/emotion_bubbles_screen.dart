import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/logic/adaptive_engine.dart';
import '../features/child/presentation/help_button.dart';
import '../features/child/presentation/activity_exit_handler.dart';
import '../features/child/presentation/completion_feedback_overlay.dart';
import '../core/services/emotion_colour_mapping.dart';
import '../core/services/star_service.dart';
import '../features/child/services/activity_progress_service.dart';

/// Emotion Bubbles Pop — Colored bubbles float up, child taps the one
/// matching the target emotion-color. Adaptive difficulty via AdaptiveEngine.
class EmotionBubblesScreen extends StatefulWidget {
  const EmotionBubblesScreen({super.key});

  @override
  State<EmotionBubblesScreen> createState() => _EmotionBubblesScreenState();
}

class _Bubble {
  double x; // 0..1 fraction of screen width
  double y; // starts > 1, floats up to < 0
  final double speed; // fraction per tick
  final double size;
  final Color color;
  final String emotionName;
  final String emoji;
  bool popped = false;

  _Bubble({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.color,
    required this.emotionName,
    required this.emoji,
  });
}

class _EmotionBubblesScreenState extends State<EmotionBubblesScreen> {
  static const String _activityId = 'game_bubble_pop';
  final ActivityProgressService _progressService = ActivityProgressService();

  final Random _rng = Random();
  final AdaptiveEngine _engine = AdaptiveEngine(
    frustrationThreshold: 3,
    overloadTapsPerSecond: 6.0,
  );

  // Emotion–color mapping (reads user's personalised colours)
  late final List<Map<String, dynamic>> _emotions = [
    {
      'name': 'Happy',
      'emoji': '😊',
      'color': EmotionColourMapping.colorFor('Happy')
    },
    {
      'name': 'Sad',
      'emoji': '😢',
      'color': EmotionColourMapping.colorFor('Sad')
    },
    {
      'name': 'Angry',
      'emoji': '😡',
      'color': EmotionColourMapping.colorFor('Angry')
    },
    {
      'name': 'Calm',
      'emoji': '😌',
      'color': EmotionColourMapping.colorFor('Calm')
    },
    {
      'name': 'Scared',
      'emoji': '😨',
      'color': EmotionColourMapping.colorFor('Scared')
    },
    {
      'name': 'Excited',
      'emoji': '🤩',
      'color': EmotionColourMapping.colorFor('Excited')
    },
    {
      'name': 'Love',
      'emoji': '🥰',
      'color': EmotionColourMapping.colorFor('Love')
    },
    {
      'name': 'Surprised',
      'emoji': '😲',
      'color': EmotionColourMapping.colorFor('Surprised')
    },
    {'name': 'Shy', 'emoji': '😳', 'color': const Color(0xFFFFB7C5)},
    {'name': 'Proud', 'emoji': '😎', 'color': const Color(0xFF6366F1)},
    {'name': 'Silly', 'emoji': '🤪', 'color': const Color(0xFFFBBF24)},
    {'name': 'Grateful', 'emoji': '☺️', 'color': const Color(0xFF34D399)},
    {'name': 'Tired', 'emoji': '😴', 'color': const Color(0xFF94A3B8)},
    {'name': 'Bored', 'emoji': '🥱', 'color': const Color(0xFFD4D4D8)},
    {'name': 'Confused', 'emoji': '🤔', 'color': const Color(0xFFA78BFA)},
    {'name': 'Hopeful', 'emoji': '🤗', 'color': const Color(0xFFFCD34D)},
    {'name': 'Nervous', 'emoji': '😬', 'color': const Color(0xFFFB923C)},
    {'name': 'Lonely', 'emoji': '🥺', 'color': const Color(0xFF7DD3FC)},
    {'name': 'Playful', 'emoji': '😜', 'color': const Color(0xFFF472B6)},
    {'name': 'Peaceful', 'emoji': '😇', 'color': const Color(0xFFA7F3D0)},
  ];

  late Map<String, dynamic> _targetEmotion;
  final List<_Bubble> _bubbles = [];
  Timer? _ticker;
  int _score = 0;
  int _round = 0;
  final int _maxRounds = 20;
  bool _showFeedback = false;
  bool _feedbackCorrect = false;
  bool _gameOver = false;

  // Difficulty (adaptive)
  int _numBubbles = 4; // how many on screen at once
  double _baseSpeed = 0.003;

  @override
  void initState() {
    super.initState();
    _pickTarget();
    _spawnBubbles();
    _ticker = Timer.periodic(const Duration(milliseconds: 30), (_) => _tick());
    _restoreProgress();
  }

  Future<void> _restoreProgress() async {
    final saved = await _progressService.loadProgress(_activityId);
    if (!mounted || saved == null) return;
    final data = saved.progressData;
    final savedScore = data['score'];
    final savedRound = data['round'];
    final savedNumBubbles = data['numBubbles'];
    final savedBaseSpeed = data['baseSpeed'];
    final savedTargetName = data['targetEmotionName'];
    if (savedScore is! int || savedRound is! int ||
        savedNumBubbles is! int || savedBaseSpeed is! double ||
        savedTargetName is! String) { return; }
    // Find matching emotion
    final matchedEmotion = _emotions.firstWhere(
      (e) => e['name'] == savedTargetName,
      orElse: () => _emotions.first,
    );
    setState(() {
      _score = savedScore;
      _round = savedRound.clamp(0, _maxRounds - 1);
      _numBubbles = savedNumBubbles.clamp(3, 6);
      _baseSpeed = savedBaseSpeed.clamp(0.001, 0.006);
      _targetEmotion = matchedEmotion;
    });
    _spawnBubbles();
  }

  Map<String, dynamic> _buildProgressData() => {
    'score': _score,
    'round': _round,
    'numBubbles': _numBubbles,
    'baseSpeed': _baseSpeed,
    'targetEmotionName': _targetEmotion['name'] as String,
  };

  Future<void> _handleReturnPressed() async {
    // Pause the ticker while dialog is shown
    _ticker?.cancel();
    _ticker = null;
    await ActivityExitHandler.handleExitActivity(
      context: context,
      activityId: _activityId,
      activityEmoji: '🫧',
      buildProgressData: _buildProgressData,
    );
    // If still mounted, user chose Keep Playing — restart ticker
    if (mounted) {
      _ticker = Timer.periodic(const Duration(milliseconds: 30), (_) => _tick());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _pickTarget() {
    _targetEmotion = _emotions[_rng.nextInt(_emotions.length)];
    _engine.markPromptShown();
  }

  void _spawnBubbles() {
    _bubbles.clear();
    // Always include the target at least once
    final pool = List<Map<String, dynamic>>.from(_emotions);
    pool.shuffle(_rng);
    // Ensure target is in the set
    final selected = <Map<String, dynamic>>[_targetEmotion];
    for (final e in pool) {
      if (selected.length >= _numBubbles) break;
      if (e['name'] != _targetEmotion['name']) selected.add(e);
    }
    selected.shuffle(_rng);

    // Distribute bubbles evenly across x so they never overlap
    final step = 0.8 / selected.length; // e.g. 4 bubbles -> 0.2 apart
    for (int i = 0; i < selected.length; i++) {
      final e = selected[i];
      _bubbles.add(_Bubble(
        x: 0.1 + step * i + _rng.nextDouble() * step * 0.5,
        y: 1.0 + _rng.nextDouble() * 0.5,
        speed: _baseSpeed + _rng.nextDouble() * 0.002,
        size: 110 + _rng.nextDouble() * 42,
        color: e['color'] as Color,
        emotionName: e['name'] as String,
        emoji: e['emoji'] as String,
      ));
    }
  }

  void _tick() {
    if (_gameOver || _showFeedback) return;
    setState(() {
      for (final b in _bubbles) {
        if (!b.popped) {
          b.y -= b.speed;
        }
      }
      // Remove bubbles that floated off-screen
      _bubbles.removeWhere((b) => b.y < -0.2 && !b.popped);
      // If all gone without correct tap, respawn
      if (_bubbles.where((b) => !b.popped).isEmpty) {
        _engine.trackError();
        _adaptDifficulty();
        _spawnBubbles();
      }
    });
  }

  void _onBubbleTap(_Bubble bubble) {
    _engine.recordTap();
    _engine.recordTapLatency();

    if (bubble.emotionName == _targetEmotion['name']) {
      // Correct!
      setState(() {
        bubble.popped = true;
        _score++;
        _feedbackCorrect = true;
        _showFeedback = true;
        _engine.resetErrors();
      });
      // Award 1 star per correct pop
      StarService.addStars(StarService.emotionBubbles, 1);
    } else {
      // Wrong
      setState(() {
        bubble.popped = true;
        _feedbackCorrect = false;
        _showFeedback = true;
        _engine.trackError();
      });
    }

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _round++;
      if (_round >= _maxRounds) {
        // UCD018 — show completion feedback overlay.
        _ticker?.cancel();
        int stars = 0;
        if (_score >= 1) stars++;
        if (_score >= _maxRounds * 0.6) stars++;
        if (_score >= _maxRounds * 0.85) stars++;
        CompletionFeedbackOverlay.show(
          context: context,
          activityId: 'game_bubble_pop',
          activityName: 'Emotion Bubbles',
          starGameKey: StarService.emotionBubbles,
          starsEarned: stars,
          scoreValue: _score,
          scoreMax: _maxRounds,
          onPlayAgain: _restart,
        );
      } else {
        _adaptDifficulty();
        _pickTarget();
        _spawnBubbles();
        setState(() => _showFeedback = false);
      }
    });
  }

  void _adaptDifficulty() {
    if (_engine.isFrustrated) {
      // Make easier
      _numBubbles = max(3, _numBubbles - 1);
      _baseSpeed = max(0.001, _baseSpeed - 0.0005);
    } else if (_score > _round * 0.7) {
      // Doing great → harder
      _numBubbles = min(6, _numBubbles + 1);
      _baseSpeed = min(0.006, _baseSpeed + 0.0005);
    }
    if (_engine.isOverloaded) {
      _baseSpeed = max(0.001, _baseSpeed - 0.001);
    }
  }

  void _restart() {
    _engine.reset();
    _score = 0;
    _round = 0;
    _gameOver = false;
    _showFeedback = false;
    _numBubbles = 4;
    _baseSpeed = 0.003;
    _pickTarget();
    _spawnBubbles();
    setState(() {});
  }

  TextStyle _cute(
      {double size = 24,
      FontWeight weight = FontWeight.w700,
      Color color = Colors.white}) {
    return GoogleFonts.baloo2(fontSize: size, fontWeight: weight, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

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
            colors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2), Color(0xFF80DEEA)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Floating bubbles
              ..._bubbles.where((b) => !b.popped).map((b) {
                return Positioned(
                  left: b.x * w - b.size / 2,
                  top: b.y * h - b.size / 2,
                  child: GestureDetector(
                    onTap: () => _onBubbleTap(b),
                    child: AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: b.size,
                        height: b.size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: const Alignment(-0.3, -0.3),
                            colors: [
                              b.color.withValues(alpha: 0.9),
                              b.color,
                              b.color.withValues(alpha: 0.6),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: b.color.withValues(alpha: 0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.6),
                              width: 3),
                        ),
                        child: Center(
                          child: Text(b.emoji,
                              style: TextStyle(fontSize: b.size * 0.54)),
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // Header: target prompt (compact single row like Emotion Path)
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 30),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7E6).withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.8),
                        width: 3,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Pop: ',
                            style: _cute(size: 24, color: Colors.black87)),
                        Text(_targetEmotion['emoji'],
                            style: const TextStyle(fontSize: 42)),
                        const SizedBox(width: 8),
                        Text(
                          _targetEmotion['name'],
                          style: _cute(
                              size: 31,
                              weight: FontWeight.w900,
                              color: const Color(0xFF1F2937)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Score + Hint side by side
              Positioned(
                top: 20,
                right: 20,
                child: Row(
                  children: [
                    const HelpButton(
                      activityId: 'game_bubble_pop',
                      activityEmoji: '🫧',
                      activityName: 'Bubble Pop',
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B21A8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('⭐ $_score / $_maxRounds',
                          style: _cute(size: 22)),
                    ),
                  ],
                ),
              ),

              // Feedback overlay
              if (_showFeedback)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: _feedbackCorrect
                          ? const Color(0xFF4ECDC4)
                          : const Color(0xFFFF6B6B),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 20)
                      ],
                    ),
                    child: Text(
                      _feedbackCorrect ? '✨ Great Job! ✨' : '🤔 Try Again!',
                      style: _cute(size: 36, weight: FontWeight.w900),
                    ),
                  ),
                ),

              // Game over
              if (_gameOver)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    margin: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 20)
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🎉', style: TextStyle(fontSize: 70)),
                        const SizedBox(height: 16),
                        Text('Amazing!',
                            style: _cute(
                                size: 40,
                                weight: FontWeight.w900,
                                color: const Color(0xFF6B21A8))),
                        const SizedBox(height: 10),
                        Text('You got $_score / $_maxRounds',
                            style: _cute(size: 28, color: Colors.black54)),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _restart,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4ECDC4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25)),
                          ),
                          child: Text('Play Again! 🔄', style: _cute(size: 24)),
                        ),
                      ],
                    ),
                  ),
                ),

              // Back button (UCD016: exit with save prompt)
              Positioned(
                top: 20,
                left: 20,
                child: GestureDetector(
                  onTap: _handleReturnPressed,
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 34),
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
