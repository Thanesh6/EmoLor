import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/logic/adaptive_engine.dart';
import '../core/services/star_service.dart';
import '../core/widgets/star_reward_widget.dart';
import '../features/child/presentation/help_button.dart';
import '../features/child/presentation/activity_exit_handler.dart';
import '../features/child/presentation/completion_feedback_overlay.dart';
import '../core/services/emotion_colour_mapping.dart';

/// Game 1 — Emotion Path: Sequence Decision Game
///
/// Help a character reach the destination by selecting a safe emotional path.
/// Tap stepping stones matching the target emotion in sequence. Calm,
/// adaptive, autism-friendly.
class EmotionPathScreen extends StatefulWidget {
  const EmotionPathScreen({super.key});

  @override
  State<EmotionPathScreen> createState() => _EmotionPathScreenState();
}

class _EmotionPathScreenState extends State<EmotionPathScreen>
    with TickerProviderStateMixin {
  // ── Emotion palette (reads user's personalised colours) ──
  late final List<Map<String, dynamic>> _emotions = [
    {
      'name': 'Happy',
      'emoji': '😄',
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
      'name': 'Love',
      'emoji': '🥰',
      'color': EmotionColourMapping.colorFor('Love')
    },
    {
      'name': 'Calm',
      'emoji': '😌',
      'color': EmotionColourMapping.colorFor('Calm')
    },
    {
      'name': 'Surprised',
      'emoji': '😲',
      'color': EmotionColourMapping.colorFor('Surprised')
    },
  ];

  final Random _rng = Random();
  final AdaptiveEngine _engine = AdaptiveEngine(
    hesitationThresholdMs: 10000,
    frustrationThreshold: 3,
    overloadTapsPerSecond: 5.0,
  );

  // ── Level state ──
  int _level = 1;
  int _pathLength = 3; // stones to find
  late Map<String, dynamic> _targetEmotion;
  List<_Stone> _stones = [];
  int _nextStoneIdx = 0; // which correct stone the child should tap next
  int _incorrectTaps = 0;
  bool _frustrationTriggered = false;
  bool _showHints = false;
  bool _levelComplete = false;
  bool _gameComplete = false;

  // Character position (frac along path)
  double _characterProgress = 0;
  late AnimationController _charController;
  late AnimationController _hintPulseController;

  @override
  void initState() {
    super.initState();
    _charController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _charController, curve: Curves.easeInOut),
    );
    _hintPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _buildLevel();
  }

  @override
  void dispose() {
    _charController.dispose();
    _hintPulseController.dispose();
    super.dispose();
  }

  // ── Level generation ──
  void _buildLevel() {
    _engine.reset();
    _targetEmotion = _emotions[_rng.nextInt(_emotions.length)];
    _nextStoneIdx = 0;
    _incorrectTaps = 0;
    _frustrationTriggered = false;
    _showHints = false;
    _levelComplete = false;
    _characterProgress = 0;
    _charController.reset();

    // Total visible stones = pathLength * 2 (mixed correct / wrong)
    final totalStones = _pathLength * 2;
    // Positions of correct stones (sorted, from indices 0..totalStones-1)
    final correctPositions = <int>{};
    while (correctPositions.length < _pathLength) {
      correctPositions.add(_rng.nextInt(totalStones));
    }

    _stones = List.generate(totalStones, (i) {
      final isCorrect = correctPositions.contains(i);
      final emo = isCorrect
          ? _targetEmotion
          : _emotions[_rng.nextInt(_emotions.length)];
      // Don't accidentally put target on a wrong stone
      final emotion = (!isCorrect && emo['name'] == _targetEmotion['name'])
          ? _emotions[(_emotions.indexOf(emo) + 1) % _emotions.length]
          : emo;
      return _Stone(emotion: emotion, isCorrect: isCorrect);
    });

    _engine.markPromptShown();
    setState(() {});

    // Start hesitation timer
    _startHesitationTimer();
  }

  Timer? _hesitationTimer;

  void _startHesitationTimer() {
    _hesitationTimer?.cancel();
    _hesitationTimer = Timer(const Duration(seconds: 10), () {
      if (!_levelComplete && mounted) {
        setState(() => _showHints = true);
      }
    });
  }

  // ── Stone tap ──
  void _onStoneTap(int index) {
    if (_levelComplete || _gameComplete) return;
    _engine.recordTap();

    // Overload check
    if (_engine.isOverloaded) {
      // Brief pause
      return;
    }

    _hesitationTimer?.cancel();
    final stone = _stones[index];

    if (stone.selected || stone.wrong) return;

    if (stone.isCorrect) {
      // Find which sequential correct stone this is
      final correctIndices = <int>[];
      for (int i = 0; i < _stones.length; i++) {
        if (_stones[i].isCorrect) correctIndices.add(i);
      }
      if (correctIndices.indexOf(index) == _nextStoneIdx) {
        setState(() {
          stone.selected = true;
          _nextStoneIdx++;
          _engine.resetErrors();
        });
        _engine.recordTapLatency();
        _engine.markPromptShown();
        _startHesitationTimer();

        // Move character
        final target = (_nextStoneIdx) / _pathLength;
        Tween<double>(begin: _characterProgress, end: target).animate(
            CurvedAnimation(parent: _charController, curve: Curves.easeInOut));
        _charController.forward(from: 0).then((_) {
          _characterProgress = target;
        });

        if (_nextStoneIdx >= _pathLength) {
          _onLevelComplete();
        }
      } else {
        _handleIncorrect(stone);
      }
    } else {
      _handleIncorrect(stone);
    }
  }

  void _handleIncorrect(_Stone stone) {
    _engine.trackError();
    _incorrectTaps++;
    setState(() => stone.wrong = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => stone.wrong = false);
    });

    if (_engine.isFrustrated) {
      _frustrationTriggered = true;
      // Shorten path — remove some wrong stones
      if (_pathLength > 2) {
        setState(() {
          _stones.removeWhere((s) => !s.isCorrect && !s.selected);
          _showHints = true;
        });
      }
      _engine.simplifyUI();
    }
    _startHesitationTimer();
  }

  void _onLevelComplete() {
    _hesitationTimer?.cancel();
    setState(() => _levelComplete = true);

    // Calculate stars
    int stars = 1; // always 1 for completion
    if (_incorrectTaps <= 1) stars++;
    if (!_frustrationTriggered) stars++;

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_level >= 30) {
        // Game complete — show UCD018 completion feedback.
        CompletionFeedbackOverlay.show(
          context: context,
          activityId: 'game_emotion_path',
          activityName: 'Emotion Path',
          starGameKey: StarService.emotionPath,
          starsEarned: stars,
          scoreValue: _level,
          scoreMax: 30,
          onPlayAgain: () {
            setState(() {
              _level = 1;
              _pathLength = 3;
              _gameComplete = false;
              _levelComplete = false;
            });
            _buildLevel();
          },
        );
      } else {
        // Per-level reward (keep existing star logic for intermediate levels).
        StarService.addStars(StarService.emotionPath, stars);
        StarRewardWidget.show(context);
        setState(() {
          _level++;
          _pathLength = (_pathLength + 1).clamp(3, 7);
        });
        _buildLevel();
      }
    });
  }

  // ── UI ──
  TextStyle _cute(
          {double sz = 24,
          Color c = Colors.white,
          FontWeight fw = FontWeight.w700}) =>
      GoogleFonts.baloo2(fontSize: sz, fontWeight: fw, color: c);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2), Color(0xFF80DEEA)],
          ),
        ),
        child: SafeArea(
          child: _gameComplete ? _buildEndScreen() : _buildGame(),
        ),
      ),
    );
  }

  Widget _buildGame() {
    return Stack(
      children: [
        Column(
          children: [
            const SizedBox(height: 16),
            // Target
            _buildTargetBar(),
            const SizedBox(height: 10),
            // Progress
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _nextStoneIdx / _pathLength,
                  minHeight: 12,
                  backgroundColor: Colors.white54,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      _targetEmotion['color'] as Color),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Path grid
            Expanded(child: _buildPath()),
          ],
        ),
        // Back
        Positioned(
          top: 10,
          left: 10,
          child: _backButton(),
        ),
        // Level indicator
        Positioned(
          top: 10,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Level $_level',
                style: _cute(sz: 22, c: const Color(0xFF00695C))),
          ),
        ),
        // UCD015: Help button
        const Positioned(
          top: 10,
          right: 150,
          child: HelpButton(
            activityId: 'game_emotion_path',
            activityEmoji: '🛤️',
            activityName: 'Emotion Path',
          ),
        ),
      ],
    );
  }

  Widget _buildTargetBar() {
    final color = _targetEmotion['color'] as Color;
    final emoji = _targetEmotion['emoji'] as String;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 120),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color, width: 4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Find the path: ', style: _cute(sz: 22, c: Colors.black87)),
          Text(emoji, style: const TextStyle(fontSize: 68)),
          const SizedBox(width: 8),
          Text(_targetEmotion['name'] as String,
              style: _cute(sz: 24, c: color)),
        ],
      ),
    );
  }

  Widget _buildPath() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (_stones.length <= 6) ? 3 : 4;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: GridView.builder(
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: 18,
              mainAxisSpacing: 18,
            ),
            itemCount: _stones.length,
            itemBuilder: (context, i) => _buildStone(i),
          ),
        );
      },
    );
  }

  Widget _buildStone(int index) {
    final stone = _stones[index];
    final color = stone.emotion['color'] as Color;
    final emoji = stone.emotion['emoji'] as String;
    final isHinted = _showHints && stone.isCorrect && !stone.selected;

    return GestureDetector(
      onTap: () => _onStoneTap(index),
      child: AnimatedBuilder(
        animation: _hintPulseController,
        builder: (context, child) {
          final scale =
              isHinted ? 1.0 + _hintPulseController.value * 0.08 : 1.0;
          return Transform.scale(scale: scale, child: child);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: stone.selected
                ? color
                : stone.wrong
                    ? Colors.red.shade200
                    : color.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: stone.selected
                  ? Colors.white
                  : isHinted
                      ? color
                      : Colors.white54,
              width: stone.selected
                  ? 3.4
                  : isHinted
                      ? 2.5
                      : 2,
            ),
            boxShadow: stone.selected
                ? [
                    BoxShadow(
                        color: color.withValues(alpha: 0.5), blurRadius: 14)
                  ]
                : [],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                emoji,
                key: ValueKey('${index}_${stone.selected}'),
                style: TextStyle(fontSize: stone.selected ? 84 : 77),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEndScreen() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 70)),
          const SizedBox(height: 16),
          Text('Path Complete!',
              style: _cute(sz: 40, c: const Color(0xFF00695C))),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _level = 1;
                _pathLength = 3;
                _gameComplete = false;
              });
              _buildLevel();
            },
            icon: const Icon(Icons.replay),
            label: const Text('Play Again'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: _cute(sz: 22),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Back to Games', style: _cute(sz: 20, c: Colors.teal)),
          ),
        ],
      ),
    );
  }

  Widget _backButton() => GestureDetector(
        onTap: () => ActivityExitHandler.handleExitActivity(
          context: context,
          activityId: 'game_emotion_path',
          activityEmoji: '🛤️',
          buildProgressData: () => {
            'level': _level,
            'nextStoneIdx': _nextStoneIdx,
          },
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4))
            ],
          ),
          child: const Icon(Icons.arrow_back_rounded,
              color: Color(0xFF00695C), size: 28),
        ),
      );
}

// ── Data helper ──
class _Stone {
  final Map<String, dynamic> emotion;
  final bool isCorrect;
  bool selected = false;
  bool wrong = false;
  _Stone({required this.emotion, required this.isCorrect});
}
