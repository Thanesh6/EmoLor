import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/logic/adaptive_engine.dart';
import '../core/services/star_service.dart';
import '../features/caregiver/services/goal_notification_service.dart';
import '../core/widgets/star_reward_widget.dart';
import '../features/child/presentation/help_button.dart';
import '../features/child/presentation/activity_exit_handler.dart';
import '../features/child/presentation/completion_feedback_overlay.dart';
import '../core/services/emotion_colour_mapping.dart';

/// Game 3 — Color Memory Tiles: Emotion Sequence Memory Game
///
/// Remember and repeat a sequence of emotional colors. Calm tile glow
/// sequence, replay button always available, autism-friendly.
class ColorMemoryTilesScreen extends StatefulWidget {
  const ColorMemoryTilesScreen({super.key});

  @override
  State<ColorMemoryTilesScreen> createState() => _ColorMemoryTilesScreenState();
}

class _ColorMemoryTilesScreenState extends State<ColorMemoryTilesScreen>
    with TickerProviderStateMixin {
  // ── Emotion tiles (reads user's personalised colours) ──
  late final List<Map<String, dynamic>> _tileEmotions = [
    {
      'name': 'Happy',
      'icon': Icons.sentiment_very_satisfied,
      'color': EmotionColourMapping.colorFor('Happy')
    },
    {
      'name': 'Sad',
      'icon': Icons.sentiment_dissatisfied,
      'color': EmotionColourMapping.colorFor('Sad')
    },
    {
      'name': 'Angry',
      'icon': Icons.sentiment_very_dissatisfied,
      'color': EmotionColourMapping.colorFor('Angry')
    },
    {
      'name': 'Love',
      'icon': Icons.favorite,
      'color': EmotionColourMapping.colorFor('Love')
    },
    {
      'name': 'Calm',
      'icon': Icons.spa,
      'color': EmotionColourMapping.colorFor('Calm')
    },
    {
      'name': 'Surprised',
      'icon': Icons.emoji_emotions,
      'color': EmotionColourMapping.colorFor('Surprised')
    },
  ];

  final Random _rng = Random();
  final AdaptiveEngine _engine = AdaptiveEngine(
    hesitationThresholdMs: 10000,
    frustrationThreshold: 3,
    overloadTapsPerSecond: 5.0,
  );

  // Game state
  int _tileCount = 4; // visible tiles (grows to 6)
  int _seqLength = 2; // target sequence length
  int _level = 1;
  List<int> _sequence = []; // indices into the visible tiles
  List<int> _playerInput = [];
  bool _isPlaying = false; // sequence is being shown
  bool _isPlayerTurn = false;
  int _glowIdx = -1; // currently glowing tile during playback
  bool _usedReplay = false;
  bool _levelDone = false;
  bool _gameComplete = false;

  Timer? _hesitationTimer;

  @override
  void initState() {
    super.initState();
    _buildLevel();
  }

  @override
  void dispose() {
    _hesitationTimer?.cancel();
    super.dispose();
  }

  void _buildLevel() {
    _engine.reset();
    _usedReplay = false;
    _levelDone = false;
    _playerInput = [];
    _glowIdx = -1;
    _isPlayerTurn = false;
    _isPlaying = false;

    // Generate sequence
    _sequence = List.generate(_seqLength, (_) => _rng.nextInt(_tileCount));

    setState(() {});
    Future.delayed(const Duration(milliseconds: 600), _playSequence);
  }

  // ── Sequence playback ──
  Future<void> _playSequence() async {
    setState(() {
      _isPlaying = true;
      _isPlayerTurn = false;
    });
    for (int i = 0; i < _sequence.length; i++) {
      if (!mounted) return;
      setState(() => _glowIdx = _sequence[i]);
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      setState(() => _glowIdx = -1);
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (!mounted) return;
    setState(() {
      _isPlaying = false;
      _isPlayerTurn = true;
      _playerInput = [];
    });
    _engine.markPromptShown();
    _startHesitationTimer();
  }

  void _startHesitationTimer() {
    _hesitationTimer?.cancel();
    _hesitationTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isPlayerTurn && !_levelDone) {
        // Auto replay as assistance
        _usedReplay = true;
        _playSequence();
      }
    });
  }

  // ── Player input ──
  void _onTileTap(int idx) {
    if (!_isPlayerTurn || _isPlaying || _levelDone || _gameComplete) return;
    _engine.recordTap();
    _engine.recordTapLatency();
    _hesitationTimer?.cancel();

    if (_engine.isOverloaded) {
      // Pause briefly
      setState(() => _isPlayerTurn = false);
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) setState(() => _isPlayerTurn = true);
      });
      return;
    }

    final step = _playerInput.length;
    if (idx == _sequence[step]) {
      // Correct
      _engine.resetErrors();
      setState(() {
        _playerInput.add(idx);
        _glowIdx = idx;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _glowIdx = -1);
      });

      if (_playerInput.length == _sequence.length) {
        _onLevelComplete();
      } else {
        _engine.markPromptShown();
        _startHesitationTimer();
      }
    } else {
      // Incorrect — gently reset attempt
      _engine.trackError();
      setState(() {
        _playerInput = [];
        _glowIdx = -1;
      });
      if (_engine.isFrustrated) {
        // Shorten sequence
        if (_seqLength > 2) {
          _seqLength--;
          _sequence = _sequence.sublist(0, _seqLength);
        }
        _engine.simplifyUI();
      }
      // Replay after short pause
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _playSequence();
      });
    }
  }

  void _onReplayTap() {
    if (_isPlaying || _levelDone || _gameComplete) return;
    _usedReplay = true;
    _playerInput = [];
    _playSequence();
  }

  void _onLevelComplete() {
    _hesitationTimer?.cancel();
    setState(() {
      _levelDone = true;
      _isPlayerTurn = false;
    });

    // Stars
    int stars = 1; // completed
    if (_seqLength >=
        (_level <= 3
            ? 2
            : _level <= 6
                ? 3
                : 4)) {
      stars++; // met target
    }
    if (!_usedReplay) {
      stars++; // no replay
    }

    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;
      if (_level >= 8) {
        // UCD018 — show completion feedback overlay.
        CompletionFeedbackOverlay.show(
          context: context,
          activityId: 'game_color_memory',
          activityName: 'Color Memory Tiles',
          starGameKey: StarService.colorMemory,
          starsEarned: stars,
          scoreValue: _level,
          scoreMax: 8,
          onPlayAgain: () {
            _level = 1;
            _seqLength = 2;
            _tileCount = 4;
            _gameComplete = false;
            _buildLevel();
          },
        );
      } else {
        // Per-level reward.
        await StarService.addStars(StarService.colorMemory, stars);
        if (mounted) {
          await GoalNotificationService.instance.checkAllActiveStarGoals(
            context: context,
            deltaStars: stars,
          );
        }
        StarRewardWidget.show(context);
        _level++;
        if (_level % 2 == 0 && _seqLength < 6) _seqLength++;
        if (_level == 4 && _tileCount < 5) _tileCount = 5;
        if (_level == 6 && _tileCount < 6) _tileCount = 6;
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
            colors: [Color(0xFFEDE7F6), Color(0xFFD1C4E9), Color(0xFFB39DDB)],
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
            Text(
              _isPlaying
                  ? '👀 Watch carefully…'
                  : _levelDone
                      ? '🎉 Correct!'
                      : '🧠 Your turn!',
              style: _cute(sz: 28, c: const Color(0xFF4A148C)),
            ),
            const SizedBox(height: 8),
            // Progress dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_sequence.length, (i) {
                final done = i < _playerInput.length;
                return Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: done ? const Color(0xFF7C4DFF) : Colors.white54,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                );
              }),
            ),
            const Spacer(),
            // Tiles
            _buildTileGrid(),
            const Spacer(),
            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _iconBtn(Icons.replay_rounded, 'Replay', _onReplayTap),
                const SizedBox(width: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Level $_level',
                      style: _cute(sz: 20, c: const Color(0xFF4A148C))),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
        Positioned(top: 10, left: 10, child: _backButton()),
        // UCD015: Help button
        const Positioned(
          top: 10,
          right: 10,
          child: HelpButton(
            activityId: 'game_color_memory',
            activityEmoji: '🧠',
            activityName: 'Color Memory',
          ),
        ),
      ],
    );
  }

  Widget _buildTileGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 20,
        runSpacing: 20,
        children: List.generate(_tileCount, _buildTile),
      ),
    );
  }

  Widget _buildTile(int idx) {
    final emo = _tileEmotions[idx % _tileEmotions.length];
    final color = emo['color'] as Color;
    final isGlowing = _glowIdx == idx;
    return GestureDetector(
      onTap: () => _onTileTap(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: isGlowing ? color : color.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: isGlowing ? Colors.white : color.withValues(alpha: 0.6),
              width: isGlowing ? 5 : 3),
          boxShadow: isGlowing
              ? [
                  BoxShadow(
                      color: color.withValues(alpha: 0.7),
                      blurRadius: 24,
                      spreadRadius: 4)
                ]
              : [],
        ),
        child: Center(
          child: Icon(emo['icon'] as IconData,
              size: 48, color: isGlowing ? Colors.white : color),
        ),
      ),
    );
  }

  Widget _buildEndScreen() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🧠✨', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          Text('Memory Master!',
              style: _cute(sz: 38, c: const Color(0xFF4A148C))),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _level = 1;
              _seqLength = 2;
              _tileCount = 4;
              _gameComplete = false;
              _buildLevel();
            },
            icon: const Icon(Icons.replay),
            label: const Text('Play Again'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              textStyle: _cute(sz: 22),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Back to Games',
                style: _cute(sz: 20, c: Colors.deepPurple)),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF7C4DFF), size: 24),
            const SizedBox(width: 6),
            Text(label, style: _cute(sz: 18, c: const Color(0xFF4A148C))),
          ],
        ),
      ),
    );
  }

  Widget _backButton() => GestureDetector(
        onTap: () => ActivityExitHandler.handleExitActivity(
          context: context,
          activityId: 'game_color_memory',
          activityName: 'Color Memory Tiles',
          activityEmoji: '🧠',
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
              color: Color(0xFF4A148C), size: 28),
        ),
      );
}
