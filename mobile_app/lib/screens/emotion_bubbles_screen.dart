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

  // Shuffled order to ensure all 48 get shown as targets
  late List<int> _targetOrder;
  int _targetIndex = 0;

  late Map<String, dynamic> _targetEmotion;
  final List<_Bubble> _bubbles = [];
  Timer? _ticker;
  int _sessionStars = 0;
  int _round = 0; // for difficulty adaptation
  bool _showFeedback = false;
  bool _feedbackCorrect = false;

  // Difficulty (adaptive)
  int _numBubbles = 4; // how many on screen at once
  double _baseSpeed = 0.003;
  int _levelErrors = 0; // errors for current target emoji

  @override
  void initState() {
    super.initState();
    _targetOrder = _buildFeelingsFirstOrder();
    _targetIndex = 0;
    _pickTarget();
    _spawnBubbles();
    _ticker = Timer.periodic(const Duration(milliseconds: 30), (_) => _tick());
    _restoreProgress();
  }

  Future<void> _restoreProgress() async {
    final saved = await _progressService.loadProgress(_activityId);
    if (!mounted || saved == null) return;
    final data = saved.progressData;
    final savedOrder = data['targetOrder'];
    final savedIndex = data['targetIndex'];
    final savedNumBubbles = data['numBubbles'];
    final savedBaseSpeed = data['baseSpeed'];
    if (savedOrder is! List ||
        savedIndex is! int ||
        savedNumBubbles is! int ||
        savedBaseSpeed is! double) {
      return;
    }
    final order = savedOrder.whereType<num>().map((n) => n.toInt()).toList();
    if (order.isEmpty || !order.every((i) => i >= 0 && i < _emotions.length)) {
      return;
    }
    setState(() {
      _targetOrder = order;
      _targetIndex = savedIndex.clamp(0, order.length);
      _numBubbles = savedNumBubbles.clamp(3, 6);
      _baseSpeed = savedBaseSpeed.clamp(0.001, 0.006);
      _sessionStars = 0; // always start at 0
      _round = _targetIndex; // approximate for difficulty
    });
    _pickTarget();
    _spawnBubbles();
  }

  Map<String, dynamic> _buildProgressData() => {
        'targetOrder': _targetOrder,
        'targetIndex': _targetIndex,
        'numBubbles': _numBubbles,
        'baseSpeed': _baseSpeed,
      };

  Future<void> _handleReturnPressed() async {
    // Pause the ticker while dialog is shown
    _ticker?.cancel();
    _ticker = null;
    await ActivityExitHandler.handleExitActivity(
      context: context,
      activityId: _activityId,
      activityName: 'EMOPOP',
      activityEmoji: '🫧',
      buildProgressData: _buildProgressData,
      starGameKey: StarService.emotionBubbles,
      sessionStars: _sessionStars,
    );
    // If still mounted, user chose Keep Playing — restart ticker
    if (mounted) {
      _ticker =
          Timer.periodic(const Duration(milliseconds: 30), (_) => _tick());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _pickTarget() {
    _targetEmotion = _emotions[_targetOrder[_targetIndex % _emotions.length]];
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
    final step = 0.8 / selected.length;
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
    if (_showFeedback) return;
    setState(() {
      for (final b in _bubbles) {
        if (!b.popped) {
          b.y -= b.speed;
        }
      }
      // Remove bubbles that floated off-screen
      _bubbles.removeWhere((b) => b.y < -0.2 && !b.popped);
      // If all gone without correct tap, respawn with easier settings
      if (_bubbles.where((b) => !b.popped).isEmpty) {
        _engine.trackError();
        _levelErrors++;
        // Reduce bubbles when they all float away
        if (_levelErrors >= 2) {
          _numBubbles = max(2, _numBubbles - 1);
        }
        _baseSpeed = max(0.001, _baseSpeed - 0.0005); // slow them down
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
        _feedbackCorrect = true;
        _showFeedback = true;
        _engine.resetErrors();
        _levelErrors = 0; // reset for next level
      });
      _sessionStars++;
      EmotionJournalService.log(
        emoji: _targetEmotion['emoji'] as String,
        emotionName: _targetEmotion['name'] as String,
        category: _targetEmotion['category'] as String,
        gameId: _activityId,
      );
    } else {
      // Wrong — track per-level error and reduce bubbles adaptively
      setState(() {
        bubble.popped = true;
        _feedbackCorrect = false;
        _showFeedback = true;
        _engine.trackError();
        _levelErrors++;
        // Adaptive: reduce bubbles on errors
        if (_levelErrors == 1) {
          _numBubbles = max(3, _numBubbles - 1);
        } else if (_levelErrors >= 2) {
          _numBubbles = max(2, _numBubbles - 1);
        }
      });
    }

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (_feedbackCorrect) {
        StarRewardWidget.show(context);
        _targetIndex++;
        // When all 48 done, reshuffle and start over
        if (_targetIndex >= _emotions.length) {
          _targetOrder = _buildFeelingsFirstOrder();
          _targetIndex = 0;
        }
      }
      _round++;
      _adaptDifficulty();
      _pickTarget();
      _spawnBubbles();
      setState(() => _showFeedback = false);
    });
  }

  void _adaptDifficulty() {
    if (_engine.isFrustrated) {
      // Make easier
      _numBubbles = max(3, _numBubbles - 1);
      _baseSpeed = max(0.001, _baseSpeed - 0.0005);
    } else if (_sessionStars > _round * 0.7) {
      // Doing great → harder
      _numBubbles = min(6, _numBubbles + 1);
      _baseSpeed = min(0.006, _baseSpeed + 0.0005);
    }
    if (_engine.isOverloaded) {
      _baseSpeed = max(0.001, _baseSpeed - 0.001);
    }
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

                // Header: target prompt
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

                // Hint + Star
                Positioned(
                  top: 14,
                  right: 16,
                  child: Row(
                    children: [
                      const HelpButton(
                        activityId: 'game_bubble_pop',
                        activityEmoji: '🫧',
                        activityName: 'EMOPOP',
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 19, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B21A8),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Text('⭐ $_sessionStars',
                            style: _cute(size: 26)),
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

                // Back button
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
