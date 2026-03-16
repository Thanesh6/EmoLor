import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/logic/adaptive_engine.dart';
import '../core/services/star_service.dart';
import '../features/child/presentation/help_button.dart';
import '../features/child/presentation/activity_exit_handler.dart';
import '../features/child/presentation/completion_feedback_overlay.dart';
import '../core/services/emotion_colour_mapping.dart';

/// Game 2 — Safe or Not?: Binary Emotion Judgment Game
///
/// Decide whether a situation matches the target emotion.
/// One item at a time, two large decision zones. Calm, binary, autism-friendly.
class SafeOrNotScreen extends StatefulWidget {
  const SafeOrNotScreen({super.key});

  @override
  State<SafeOrNotScreen> createState() => _SafeOrNotScreenState();
}

class _SafeOrNotScreenState extends State<SafeOrNotScreen>
    with TickerProviderStateMixin {
  // ── Emotion items (reads user's personalised colours) ──
  late final List<Map<String, dynamic>> _allItems = [
    {
      'emoji': '😊',
      'emotion': 'Happy',
      'color': EmotionColourMapping.colorFor('Happy')
    },
    {
      'emoji': '😢',
      'emotion': 'Sad',
      'color': EmotionColourMapping.colorFor('Sad')
    },
    {
      'emoji': '😡',
      'emotion': 'Angry',
      'color': EmotionColourMapping.colorFor('Angry')
    },
    {
      'emoji': '🥰',
      'emotion': 'Love',
      'color': EmotionColourMapping.colorFor('Love')
    },
    {
      'emoji': '😨',
      'emotion': 'Scared',
      'color': EmotionColourMapping.colorFor('Scared')
    },
    {
      'emoji': '😎',
      'emotion': 'Cool',
      'color': EmotionColourMapping.colorFor('Cool')
    },
    {
      'emoji': '😲',
      'emotion': 'Surprised',
      'color': EmotionColourMapping.colorFor('Surprised')
    },
    {
      'emoji': '🤗',
      'emotion': 'Kind',
      'color': EmotionColourMapping.colorFor('Kind')
    },
    {
      'emoji': '😤',
      'emotion': 'Angry',
      'color': EmotionColourMapping.colorFor('Angry')
    },
    {
      'emoji': '😌',
      'emotion': 'Calm',
      'color': EmotionColourMapping.colorFor('Calm')
    },
    {
      'emoji': '🥺',
      'emotion': 'Sad',
      'color': EmotionColourMapping.colorFor('Sad')
    },
    {
      'emoji': '🤩',
      'emotion': 'Happy',
      'color': EmotionColourMapping.colorFor('Happy')
    },
    {
      'emoji': '😰',
      'emotion': 'Scared',
      'color': EmotionColourMapping.colorFor('Scared')
    },
    {
      'emoji': '🫣',
      'emotion': 'Surprised',
      'color': EmotionColourMapping.colorFor('Surprised')
    },
    {
      'emoji': '🤬',
      'emotion': 'Angry',
      'color': EmotionColourMapping.colorFor('Angry')
    },
    {
      'emoji': '😴',
      'emotion': 'Calm',
      'color': EmotionColourMapping.colorFor('Calm')
    },
  ];

  static const List<String> _targetEmotions = [
    'Happy',
    'Sad',
    'Angry',
    'Love',
    'Scared',
    'Cool',
    'Surprised',
    'Calm',
    'Kind',
  ];

  final Random _rng = Random();
  final AdaptiveEngine _engine = AdaptiveEngine(
    hesitationThresholdMs: 10000,
    frustrationThreshold: 3,
    overloadTapsPerSecond: 5.0,
  );

  // Session state
  late String _targetEmotion;
  late List<Map<String, dynamic>> _sessionItems;
  int _currentIdx = 0;
  int _totalAttempts = 0;
  int _correctAnswers = 0;
  bool _frustrationTriggered = false;
  bool _overloadTriggered = false;
  bool _sessionDone = false;
  bool _showFeedback = false;
  bool? _lastCorrect;

  static const int _itemsPerSession = 10;

  late AnimationController _feedbackController;
  late AnimationController _hintController;
  Timer? _hesitationTimer;

  @override
  void initState() {
    super.initState();
    _feedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _startSession();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    _hintController.dispose();
    _hesitationTimer?.cancel();
    super.dispose();
  }

  void _startSession() {
    _engine.reset();
    _targetEmotion = _targetEmotions[_rng.nextInt(_targetEmotions.length)];
    final shuffled = List<Map<String, dynamic>>.from(_allItems)..shuffle(_rng);
    _sessionItems = shuffled.take(_itemsPerSession).toList();
    _currentIdx = 0;
    _totalAttempts = 0;
    _correctAnswers = 0;
    _frustrationTriggered = false;
    _overloadTriggered = false;
    _sessionDone = false;
    _showFeedback = false;
    _engine.markPromptShown();
    _startHesitationTimer();
    setState(() {});
  }

  void _startHesitationTimer() {
    _hesitationTimer?.cancel();
    _hesitationTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && !_sessionDone) {
        // Show subtle cue — highlight correct zone
        setState(() {});
      }
    });
  }

  void _onDecision(bool feelsOk) {
    if (_showFeedback || _sessionDone) return;
    _engine.recordTap();
    _engine.recordTapLatency();
    _hesitationTimer?.cancel();

    if (_engine.isOverloaded) {
      _overloadTriggered = true;
      return; // swallow rapid taps
    }

    _totalAttempts++;
    final item = _sessionItems[_currentIdx];
    final matchesTarget = item['emotion'] == _targetEmotion;
    final isCorrect =
        (feelsOk && matchesTarget) || (!feelsOk && !matchesTarget);

    if (isCorrect) {
      _correctAnswers++;
      _engine.resetErrors();
    } else {
      _engine.trackError();
      if (_engine.isFrustrated) {
        _frustrationTriggered = true;
        _engine.simplifyUI();
      }
    }

    setState(() {
      _lastCorrect = isCorrect;
      _showFeedback = true;
    });
    _feedbackController.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (_currentIdx + 1 >= _sessionItems.length) {
        _endSession();
      } else {
        setState(() {
          _currentIdx++;
          _showFeedback = false;
        });
        _engine.markPromptShown();
        _startHesitationTimer();
      }
    });
  }

  void _endSession() {
    _hesitationTimer?.cancel();
    final accuracy =
        _totalAttempts > 0 ? _correctAnswers / _totalAttempts : 0.0;
    final accuracyThreshold = _frustrationTriggered ? 0.50 : 0.70;

    int stars = 0;
    if (_totalAttempts >= 5) stars++; // participated
    if (accuracy >= accuracyThreshold) stars++;
    if (!_overloadTriggered) stars++;

    // UCD018 — show completion feedback overlay.
    CompletionFeedbackOverlay.show(
      context: context,
      activityId: 'game_safe_or_not',
      activityName: 'Safe or Not?',
      starGameKey: StarService.safeOrNot,
      starsEarned: stars,
      scoreValue: _correctAnswers,
      scoreMax: _totalAttempts,
      onPlayAgain: _startSession,
    );
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
            colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2), Color(0xFFFFCC80)],
          ),
        ),
        child: SafeArea(
          child: _sessionDone ? _buildResults() : _buildGame(),
        ),
      ),
    );
  }

  Widget _buildGame() {
    final item = _sessionItems[_currentIdx];
    return Stack(
      children: [
        Column(
          children: [
            const SizedBox(height: 16),
            // Target
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 22),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFFF9800), width: 3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Is this ', style: _cute(sz: 22, c: Colors.black87)),
                  Text(_targetEmotion,
                      style: _cute(sz: 26, c: const Color(0xFFFF6D00))),
                  Text(' ?', style: _cute(sz: 22, c: Colors.black87)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Progress
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_currentIdx + 1) / _sessionItems.length,
                  minHeight: 10,
                  backgroundColor: Colors.white54,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFFF9800)),
                ),
              ),
            ),
            const Spacer(),
            // Item
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                item['emoji'] as String,
                key: ValueKey(_currentIdx),
                style: const TextStyle(fontSize: 110),
              ),
            ),
            if (_showFeedback)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _lastCorrect == true ? '✅ Great!' : '❌ Try again!',
                  style: _cute(
                      sz: 26,
                      c: _lastCorrect == true
                          ? Colors.green
                          : Colors.redAccent),
                ),
              ),
            const Spacer(),
            // Decision zones
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Row(
                children: [
                  Expanded(
                      child: _buildZone(true, 'Feels OK',
                          Icons.thumb_up_alt_rounded, const Color(0xFF66BB6A))),
                  const SizedBox(width: 24),
                  Expanded(
                      child: _buildZone(
                          false,
                          'Feels Not OK',
                          Icons.thumb_down_alt_rounded,
                          const Color(0xFFEF5350))),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
        // Back
        Positioned(
          top: 10,
          left: 10,
          child: _backButton(),
        ),
        // UCD015: Help button
        const Positioned(
          top: 10,
          right: 10,
          child: HelpButton(
            activityId: 'game_safe_or_not',
            activityEmoji: '🤔',
            activityName: 'Safe or Not?',
          ),
        ),
      ],
    );
  }

  Widget _buildZone(bool feelsOk, String label, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => _onDecision(feelsOk),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white, width: 5),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 52, color: Colors.white),
            const SizedBox(height: 8),
            Text(label, style: _cute(sz: 20), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    final pct = _totalAttempts > 0
        ? (_correctAnswers * 100 / _totalAttempts).round()
        : 0;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          Text('Session Complete!',
              style: _cute(sz: 36, c: const Color(0xFFE65100))),
          const SizedBox(height: 16),
          Text('$pct% correct ($_correctAnswers / $_totalAttempts)',
              style: _cute(sz: 22, c: Colors.brown)),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _startSession,
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
                style: _cute(sz: 20, c: Colors.deepOrange)),
          ),
        ],
      ),
    );
  }

  Widget _backButton() => GestureDetector(
        onTap: () => ActivityExitHandler.handleExitActivity(
          context: context,
          activityId: 'game_safe_or_not',
          activityEmoji: '🤔',
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
              color: Color(0xFFE65100), size: 28),
        ),
      );
}
