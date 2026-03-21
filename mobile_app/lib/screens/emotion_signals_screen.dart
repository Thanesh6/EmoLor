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

/// Game 6 — Emotion Signals: Observation & Pattern Recognition Game
///
/// Identify emotional signals based on motion or rhythm patterns.
/// Tap only when the signal matches the target emotion's pattern.
/// Calm, slow transitions, autism-friendly.
class EmotionSignalsScreen extends StatefulWidget {
  const EmotionSignalsScreen({super.key});

  @override
  State<EmotionSignalsScreen> createState() => _EmotionSignalsScreenState();
}

class _EmotionSignalsScreenState extends State<EmotionSignalsScreen>
    with TickerProviderStateMixin {
  // ── Signal patterns (reads user's personalised colours) ──
  // Each emotion has a distinct animation pattern (speed, style, color)
  late final List<Map<String, dynamic>> _emotions = [
    {
      'name': 'Happy',
      'color': EmotionColourMapping.colorFor('Happy'),
      'icon': Icons.sentiment_very_satisfied,
      'patternLabel': 'Quick Pulse',
      'durationMs': 800,
    },
    {
      'name': 'Sad',
      'color': EmotionColourMapping.colorFor('Sad'),
      'icon': Icons.sentiment_dissatisfied,
      'patternLabel': 'Slow Wave',
      'durationMs': 2000,
    },
    {
      'name': 'Calm',
      'color': EmotionColourMapping.colorFor('Calm'),
      'icon': Icons.spa,
      'patternLabel': 'Gentle Glow',
      'durationMs': 1500,
    },
    {
      'name': 'Angry',
      'color': EmotionColourMapping.colorFor('Angry'),
      'icon': Icons.sentiment_very_dissatisfied,
      'patternLabel': 'Sharp Shake',
      'durationMs': 600,
    },
    {
      'name': 'Love',
      'color': EmotionColourMapping.colorFor('Love'),
      'icon': Icons.favorite,
      'patternLabel': 'Warm Throb',
      'durationMs': 1200,
    },
  ];

  final Random _rng = Random();
  final AdaptiveEngine _engine = AdaptiveEngine(
    hesitationThresholdMs: 10000,
    frustrationThreshold: 3,
    overloadTapsPerSecond: 5.0,
  );

  // Session state
  late Map<String, dynamic> _targetEmotion;
  Map<String, dynamic>? _currentSignal;
  int _correctTaps = 0;
  int _falseTaps = 0;
  bool _frustrationTriggered = false;
  bool _sessionDone = false;
  bool _showFeedback = false;
  String _feedbackText = '';

  int _signalsShown = 0;
  static const int _signalsPerSession = 12;

  // Animation
  late AnimationController _signalController;
  late AnimationController _bgController;
  Timer? _signalTimer;

  @override
  void initState() {
    super.initState();
    _signalController = AnimationController(vsync: this);
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _startSession();
  }

  @override
  void dispose() {
    _signalController.dispose();
    _bgController.dispose();
    _signalTimer?.cancel();
    super.dispose();
  }

  void _startSession() {
    _engine.reset();
    _targetEmotion = _emotions[_rng.nextInt(_emotions.length)];
    _correctTaps = 0;
    _falseTaps = 0;
    _frustrationTriggered = false;
    _sessionDone = false;
    _signalsShown = 0;
    _currentSignal = null;
    setState(() {});
    _scheduleNext();
  }

  void _scheduleNext() {
    if (_signalsShown >= _signalsPerSession) {
      _endSession();
      return;
    }

    final delay = 2000 + _rng.nextInt(2000); // 2-4s between signals
    _signalTimer?.cancel();
    _signalTimer = Timer(Duration(milliseconds: delay), _showSignal);
  }

  void _showSignal() {
    if (_sessionDone || !mounted) return;
    final emo = _emotions[_rng.nextInt(_emotions.length)];
    final dur = emo['durationMs'] as int;
    // If overloaded, make signals slower/longer
    final adjustedDur = _engine.isOverloaded ? (dur * 1.8).round() : dur;

    _signalController.duration = Duration(milliseconds: adjustedDur);
    _signalController.reset();
    _signalController.repeat(reverse: true);

    _engine.markPromptShown();
    setState(() {
      _currentSignal = emo;
      _signalsShown++;
      _showFeedback = false;
    });

    // Signal stays visible for ~adjustedDur*2 then fades
    Timer(Duration(milliseconds: adjustedDur * 3), () {
      if (!mounted || _sessionDone) return;
      if (_currentSignal == emo) {
        setState(() => _currentSignal = null);
        _signalController.stop();
        _scheduleNext();
      }
    });
  }

  void _onTap() {
    if (_sessionDone || _currentSignal == null) return;
    _engine.recordTap();
    _engine.recordTapLatency();

    if (_engine.isOverloaded) return;

    final isMatch = _currentSignal!['name'] == _targetEmotion['name'];
    if (isMatch) {
      _correctTaps++;
      _engine.resetErrors();
      setState(() {
        _feedbackText = '✅ Correct!';
        _showFeedback = true;
      });
    } else {
      _engine.trackError();
      if (!_frustrationTriggered && _engine.isFrustrated) {
        _frustrationTriggered = true;
        _engine.simplifyUI();
      }
      // If frustration triggered, ignore false taps for penalty
      if (!_frustrationTriggered) _falseTaps++;
      setState(() {
        _feedbackText = '❌ Not this one';
        _showFeedback = true;
      });
    }

    // Move to next signal
    setState(() => _currentSignal = null);
    _signalController.stop();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _showFeedback = false);
        _scheduleNext();
      }
    });
  }

  void _endSession() {
    _signalTimer?.cancel();
    _signalController.stop();

    int stars = 0;
    if (_correctTaps >= 1) stars++; // first correct tap
    if (_correctTaps >= 3) stars++; // 3 correct
    if (_falseTaps == 0 || _frustrationTriggered) {
      stars++; // no false taps (or frustrated — forgiven)
    }

    // UCD018 — show completion feedback overlay.
    if (!mounted) return;
    CompletionFeedbackOverlay.show(
      context: context,
      activityId: 'game_emotion_signals',
      activityName: 'Emotion Signals',
      starGameKey: StarService.emotionSignals,
      starsEarned: stars,
      scoreValue: _correctTaps,
      scoreMax: _signalsPerSession,
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
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          final t = _bgController.value;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(
                      const Color(0xFF1A237E), const Color(0xFF283593), t)!,
                  Color.lerp(
                      const Color(0xFF283593), const Color(0xFF3949AB), t)!,
                  Color.lerp(
                      const Color(0xFF3949AB), const Color(0xFF1A237E), t)!,
                ],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: _sessionDone ? _buildResults() : _buildGame(),
        ),
      ),
    );
  }

  Widget _buildGame() {
    final targetColor = _targetEmotion['color'] as Color;
    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Target indicator
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: targetColor.withValues(alpha: 0.6), width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Find: ', style: _cute(sz: 20)),
                    Icon(_targetEmotion['icon'] as IconData,
                        color: targetColor, size: 30),
                    const SizedBox(width: 6),
                    Text(
                      '${_targetEmotion['name']} (${_targetEmotion['patternLabel']})',
                      style: _cute(sz: 18, c: targetColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Signal area
          if (_currentSignal != null) _buildSignalWidget(),
          // Feedback
          if (_showFeedback)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Center(child: Text(_feedbackText, style: _cute(sz: 28))),
            ),
          // Score
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '✅ $_correctTaps   |   $_signalsShown/$_signalsPerSession signals',
                  style: _cute(sz: 18),
                ),
              ),
            ),
          ),
          // Instruction
          if (_currentSignal == null && !_showFeedback)
            Center(
              child: Text('Wait for a signal…',
                  style: _cute(sz: 22, c: Colors.white54)),
            ),
          // Tap hint
          if (_currentSignal != null)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                  child: Text('Tap if it matches!',
                      style: _cute(sz: 18, c: Colors.white38))),
            ),
          // Back
          Positioned(top: 10, left: 10, child: _backButton()),
          // Hint + Star (matched to Emoji Puzzle)
          Positioned(
            top: 14,
            right: 16,
            child: Row(
              children: [
                const HelpButton(
                  activityId: 'game_emotion_signals',
                  activityEmoji: '🔮',
                  activityName: 'Emotion Signals',
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 19, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B21A8),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Text('⭐ $_correctTaps', style: _cute(sz: 26)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalWidget() {
    final color = _currentSignal!['color'] as Color;
    final icon = _currentSignal!['icon'] as IconData;
    final name = _currentSignal!['name'] as String;

    return Center(
      child: AnimatedBuilder(
        animation: _signalController,
        builder: (context, _) {
          final t = _signalController.value;
          double scale = 1.0;
          Offset offset = Offset.zero;
          double opacity = 0.6 + t * 0.4;

          if (name == 'Happy') {
            // Quick pulse
            scale = 1.0 + t * 0.3;
          } else if (name == 'Sad') {
            // Slow wave
            offset = Offset(0, sin(t * pi) * 15);
            scale = 0.9 + t * 0.1;
          } else if (name == 'Calm') {
            // Gentle glow
            opacity = 0.5 + t * 0.5;
            scale = 1.0 + t * 0.05;
          } else if (name == 'Angry') {
            // Sharp shake
            offset = Offset(sin(t * pi * 4) * 8, 0);
          } else if (name == 'Love') {
            // Warm throb
            scale = 1.0 + sin(t * pi) * 0.15;
          }

          return Transform.translate(
            offset: offset,
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 4),
                    boxShadow: [
                      BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 30,
                          spreadRadius: 8)
                    ],
                  ),
                  child: Center(
                    child: Icon(icon, size: 64, color: color),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌟', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          Text('Session Complete!', style: _cute(sz: 34)),
          const SizedBox(height: 16),
          Text('Correct: $_correctTaps  |  False: $_falseTaps',
              style: _cute(sz: 22)),
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
                style: _cute(sz: 20, c: Colors.lightBlueAccent)),
          ),
        ],
      ),
    );
  }

  Widget _backButton() => GestureDetector(
        onTap: () => ActivityExitHandler.handleExitActivity(
          context: context,
          activityId: 'game_emotion_signals',
          activityEmoji: '🔮',
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4))
            ],
          ),
          child: const Icon(Icons.arrow_back_rounded,
              color: Colors.white70, size: 28),
        ),
      );
}
