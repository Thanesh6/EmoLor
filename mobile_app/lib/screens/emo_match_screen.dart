import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/star_service.dart';
import '../core/services/audio_service.dart';
import '../core/widgets/star_reward_widget.dart';
import '../core/services/emotion_journal_service.dart';
import '../features/child/presentation/help_button.dart';
import '../features/child/presentation/activity_exit_handler.dart';
import '../features/child/services/activity_progress_service.dart';

/// EmoMatch — show a daily-routine activity emoji and the child taps the
/// correct associated item from 4 choices.
/// Max 2 wrong attempts per question; after 2 fails the correct answer is
/// highlighted before the game auto-advances.
class EmoMatchScreen extends StatefulWidget {
  const EmoMatchScreen({super.key});

  @override
  State<EmoMatchScreen> createState() => _EmoMatchScreenState();
}

// ── Question model ────────────────────────────────────────────────────────────

class _Q {
  final String emoji;
  final String label;
  final String correctEmoji;
  final String correctLabel;
  final List<({String emoji, String label})> distractors;

  const _Q({
    required this.emoji,
    required this.label,
    required this.correctEmoji,
    required this.correctLabel,
    required this.distractors,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class _EmoMatchScreenState extends State<EmoMatchScreen>
    with TickerProviderStateMixin {
  static const String _activityId = 'game_emo_match';
  final ActivityProgressService _progressService = ActivityProgressService();
  final Random _rng = Random();

  // ── Question bank (20 questions) ──────────────────────────────────────────

  static const List<_Q> _bank = [
    _Q(
      emoji: '🪥',
      label: 'Toothbrush',
      correctEmoji: '🦷',
      correctLabel: 'Teeth',
      distractors: [
        (emoji: '👀', label: 'Eyes'),
        (emoji: '👂', label: 'Ears'),
        (emoji: '🤲', label: 'Hands'),
      ],
    ),
    _Q(
      emoji: '🧴',
      label: 'Soap',
      correctEmoji: '🤲',
      correctLabel: 'Hands',
      distractors: [
        (emoji: '👀', label: 'Eyes'),
        (emoji: '👃', label: 'Nose'),
        (emoji: '🦶', label: 'Feet'),
      ],
    ),
    _Q(
      emoji: '🍴',
      label: 'Fork',
      correctEmoji: '👄',
      correctLabel: 'Mouth',
      distractors: [
        (emoji: '👀', label: 'Eyes'),
        (emoji: '👂', label: 'Ears'),
        (emoji: '👃', label: 'Nose'),
      ],
    ),
    _Q(
      emoji: '🛏️',
      label: 'Bed',
      correctEmoji: '😴',
      correctLabel: 'Sleep',
      distractors: [
        (emoji: '🏃', label: 'Run'),
        (emoji: '🍽️', label: 'Eat'),
        (emoji: '📖', label: 'Read'),
      ],
    ),
    _Q(
      emoji: '👟',
      label: 'Shoes',
      correctEmoji: '🦶',
      correctLabel: 'Feet',
      distractors: [
        (emoji: '🤲', label: 'Hands'),
        (emoji: '👀', label: 'Eyes'),
        (emoji: '👃', label: 'Nose'),
      ],
    ),
    _Q(
      emoji: '🎒',
      label: 'School Bag',
      correctEmoji: '🏫',
      correctLabel: 'School',
      distractors: [
        (emoji: '🏠', label: 'Home'),
        (emoji: '🏖️', label: 'Beach'),
        (emoji: '🛒', label: 'Shop'),
      ],
    ),
    _Q(
      emoji: '🚿',
      label: 'Shower',
      correctEmoji: '🧼',
      correctLabel: 'Body',
      distractors: [
        (emoji: '🦷', label: 'Teeth'),
        (emoji: '📖', label: 'Read'),
        (emoji: '🎵', label: 'Music'),
      ],
    ),
    _Q(
      emoji: '🧢',
      label: 'Hat',
      correctEmoji: '👤',
      correctLabel: 'Head',
      distractors: [
        (emoji: '🦶', label: 'Feet'),
        (emoji: '🤲', label: 'Hands'),
        (emoji: '👃', label: 'Nose'),
      ],
    ),
    _Q(
      emoji: '🧤',
      label: 'Gloves',
      correctEmoji: '🤲',
      correctLabel: 'Hands',
      distractors: [
        (emoji: '👀', label: 'Eyes'),
        (emoji: '🦶', label: 'Feet'),
        (emoji: '👃', label: 'Nose'),
      ],
    ),
    _Q(
      emoji: '🧣',
      label: 'Scarf',
      correctEmoji: '❄️',
      correctLabel: 'Cold',
      distractors: [
        (emoji: '☀️', label: 'Hot'),
        (emoji: '🌧️', label: 'Rain'),
        (emoji: '💨', label: 'Windy'),
      ],
    ),
    _Q(
      emoji: '📚',
      label: 'Book',
      correctEmoji: '👀',
      correctLabel: 'Read',
      distractors: [
        (emoji: '🎵', label: 'Sing'),
        (emoji: '🍽️', label: 'Eat'),
        (emoji: '😴', label: 'Sleep'),
      ],
    ),
    _Q(
      emoji: '🥤',
      label: 'Cup',
      correctEmoji: '💧',
      correctLabel: 'Drink',
      distractors: [
        (emoji: '🍽️', label: 'Eat'),
        (emoji: '😴', label: 'Sleep'),
        (emoji: '🏃', label: 'Run'),
      ],
    ),
    _Q(
      emoji: '🪞',
      label: 'Mirror',
      correctEmoji: '😊',
      correctLabel: 'Face',
      distractors: [
        (emoji: '🦶', label: 'Feet'),
        (emoji: '🤲', label: 'Hands'),
        (emoji: '👂', label: 'Ears'),
      ],
    ),
    _Q(
      emoji: '🧹',
      label: 'Broom',
      correctEmoji: '🏠',
      correctLabel: 'Floor',
      distractors: [
        (emoji: '🛁', label: 'Bath'),
        (emoji: '🍽️', label: 'Eat'),
        (emoji: '🛒', label: 'Shop'),
      ],
    ),
    _Q(
      emoji: '💊',
      label: 'Medicine',
      correctEmoji: '👄',
      correctLabel: 'Mouth',
      distractors: [
        (emoji: '🤲', label: 'Hands'),
        (emoji: '👀', label: 'Eyes'),
        (emoji: '🦶', label: 'Feet'),
      ],
    ),
    _Q(
      emoji: '✏️',
      label: 'Pencil',
      correctEmoji: '✍️',
      correctLabel: 'Write',
      distractors: [
        (emoji: '📖', label: 'Read'),
        (emoji: '🎵', label: 'Sing'),
        (emoji: '🏃', label: 'Run'),
      ],
    ),
    _Q(
      emoji: '🎵',
      label: 'Music',
      correctEmoji: '👂',
      correctLabel: 'Ears',
      distractors: [
        (emoji: '👀', label: 'Eyes'),
        (emoji: '👃', label: 'Nose'),
        (emoji: '🤲', label: 'Hands'),
      ],
    ),
    _Q(
      emoji: '🌡️',
      label: 'Thermometer',
      correctEmoji: '🤒',
      correctLabel: 'Fever',
      distractors: [
        (emoji: '😴', label: 'Sleep'),
        (emoji: '🍽️', label: 'Eat'),
        (emoji: '🏃', label: 'Run'),
      ],
    ),
    _Q(
      emoji: '🧺',
      label: 'Laundry',
      correctEmoji: '👕',
      correctLabel: 'Clothes',
      distractors: [
        (emoji: '🍽️', label: 'Food'),
        (emoji: '📚', label: 'Books'),
        (emoji: '🧸', label: 'Toys'),
      ],
    ),
    _Q(
      emoji: '🪣',
      label: 'Bucket',
      correctEmoji: '💧',
      correctLabel: 'Water',
      distractors: [
        (emoji: '🍽️', label: 'Food'),
        (emoji: '📚', label: 'Books'),
        (emoji: '😴', label: 'Sleep'),
      ],
    ),
    _Q(
      emoji: '🛁',
      label: 'Bathtub',
      correctEmoji: '🧼',
      correctLabel: 'Wash',
      distractors: [
        (emoji: '🦷', label: 'Teeth'),
        (emoji: '📖', label: 'Read'),
        (emoji: '🏃', label: 'Run'),
      ],
    ),
    _Q(
      emoji: '🌙',
      label: 'Moon',
      correctEmoji: '😴',
      correctLabel: 'Bedtime',
      distractors: [
        (emoji: '🏃', label: 'Run'),
        (emoji: '🍽️', label: 'Eat'),
        (emoji: '📖', label: 'Read'),
      ],
    ),
    _Q(
      emoji: '☀️',
      label: 'Sun',
      correctEmoji: '⏰',
      correctLabel: 'Wake Up',
      distractors: [
        (emoji: '😴', label: 'Sleep'),
        (emoji: '🍽️', label: 'Eat'),
        (emoji: '📖', label: 'Read'),
      ],
    ),
    _Q(
      emoji: '🍳',
      label: 'Pan',
      correctEmoji: '🍽️',
      correctLabel: 'Cook',
      distractors: [
        (emoji: '📖', label: 'Read'),
        (emoji: '😴', label: 'Sleep'),
        (emoji: '🏃', label: 'Run'),
      ],
    ),
    _Q(
      emoji: '🚌',
      label: 'Bus',
      correctEmoji: '🏫',
      correctLabel: 'School',
      distractors: [
        (emoji: '🏠', label: 'Home'),
        (emoji: '🏖️', label: 'Beach'),
        (emoji: '🛒', label: 'Shop'),
      ],
    ),
    _Q(
      emoji: '🪴',
      label: 'Plant',
      correctEmoji: '💧',
      correctLabel: 'Water',
      distractors: [
        (emoji: '🍽️', label: 'Food'),
        (emoji: '📚', label: 'Books'),
        (emoji: '😴', label: 'Sleep'),
      ],
    ),
    _Q(
      emoji: '💉',
      label: 'Needle',
      correctEmoji: '🏥',
      correctLabel: 'Hospital',
      distractors: [
        (emoji: '🏫', label: 'School'),
        (emoji: '🏠', label: 'Home'),
        (emoji: '🛒', label: 'Shop'),
      ],
    ),
    _Q(
      emoji: '🖌️',
      label: 'Paintbrush',
      correctEmoji: '🎨',
      correctLabel: 'Art',
      distractors: [
        (emoji: '📖', label: 'Read'),
        (emoji: '🎵', label: 'Sing'),
        (emoji: '🏃', label: 'Run'),
      ],
    ),
    _Q(
      emoji: '🍼',
      label: 'Baby Bottle',
      correctEmoji: '👶',
      correctLabel: 'Baby',
      distractors: [
        (emoji: '🐱', label: 'Cat'),
        (emoji: '🌸', label: 'Flower'),
        (emoji: '🧸', label: 'Toy'),
      ],
    ),
    _Q(
      emoji: '🔦',
      label: 'Torch',
      correctEmoji: '🌙',
      correctLabel: 'Night',
      distractors: [
        (emoji: '☀️', label: 'Sunny'),
        (emoji: '🌧️', label: 'Rain'),
        (emoji: '🌈', label: 'Rainbow'),
      ],
    ),
    _Q(
      emoji: '📱',
      label: 'Phone',
      correctEmoji: '📞',
      correctLabel: 'Call',
      distractors: [
        (emoji: '📖', label: 'Read'),
        (emoji: '🎵', label: 'Music'),
        (emoji: '😴', label: 'Sleep'),
      ],
    ),
    _Q(
      emoji: '🎸',
      label: 'Guitar',
      correctEmoji: '🎵',
      correctLabel: 'Music',
      distractors: [
        (emoji: '👀', label: 'Eyes'),
        (emoji: '🤲', label: 'Hands'),
        (emoji: '🦶', label: 'Feet'),
      ],
    ),
    _Q(
      emoji: '🏋️',
      label: 'Weights',
      correctEmoji: '💪',
      correctLabel: 'Exercise',
      distractors: [
        (emoji: '😴', label: 'Sleep'),
        (emoji: '🍽️', label: 'Eat'),
        (emoji: '📖', label: 'Read'),
      ],
    ),
    _Q(
      emoji: '🎲',
      label: 'Dice',
      correctEmoji: '🎮',
      correctLabel: 'Play',
      distractors: [
        (emoji: '📖', label: 'Read'),
        (emoji: '🍽️', label: 'Eat'),
        (emoji: '😴', label: 'Sleep'),
      ],
    ),
    _Q(
      emoji: '🛒',
      label: 'Shopping Cart',
      correctEmoji: '🏪',
      correctLabel: 'Shop',
      distractors: [
        (emoji: '🏠', label: 'Home'),
        (emoji: '🏫', label: 'School'),
        (emoji: '🏥', label: 'Doctor'),
      ],
    ),
  ];

  // ── State ─────────────────────────────────────────────────────────────────

  final Stopwatch _stopwatch = Stopwatch();
  late List<_Q> _shuffled;
  int _qIndex = 0;
  int _sessionStars = 0;
  int _attempts = 0; // wrong attempts this question (max 2)

  late List<({String emoji, String label})> _options; // 4 shuffled choices
  late int _correctIdx; // index in _options of correct answer

  int? _tappedIdx; // most recently tapped option
  bool _answered = false; // locked after correct
  bool _revealAnswer = false; // show correct after 2 fails
  final List<bool> _flashRed = [false, false, false, false];

  // Animations
  late AnimationController _shakeController;
  late AnimationController _correctPulseController;
  late Animation<double> _correctPulseAnim;
  late AnimationController _enterController;
  late Animation<double> _enterAnim;
  late AnimationController _hintController; // looping glow for hint

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _correctPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _correctPulseAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.13), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.13, end: 0.95), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _correctPulseController, curve: Curves.easeInOut),
    );
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _enterAnim =
        CurvedAnimation(parent: _enterController, curve: Curves.elasticOut);
    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _shuffled = List.of(_bank)..shuffle(_rng);
    _loadQuestion();
    _stopwatch.start();
    _restoreProgress();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _correctPulseController.dispose();
    _enterController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  // ── Question management ───────────────────────────────────────────────────

  void _loadQuestion() {
    final q = _shuffled[_qIndex % _shuffled.length];
    final opts = <({String emoji, String label})>[
      (emoji: q.correctEmoji, label: q.correctLabel),
      ...q.distractors,
    ]..shuffle(_rng);
    _options = opts;
    _correctIdx = opts.indexWhere((o) => o.label == q.correctLabel);
    _attempts = 0;
    _tappedIdx = null;
    _answered = false;
    _revealAnswer = false;
    for (int i = 0; i < 4; i++) _flashRed[i] = false;
    _hintController.stop();
    _hintController.reset();
    _enterController.forward(from: 0);
  }

  _Q get _currentQ => _shuffled[_qIndex % _shuffled.length];

  Future<void> _restoreProgress() async {
    final saved = await _progressService.loadProgress(_activityId);
    if (!mounted || saved == null) return;
    final idx = saved.progressData['qIndex'];
    if (idx is int && idx > 0) {
      _qIndex = idx.clamp(0, _shuffled.length - 1);
      setState(() => _loadQuestion());
    }
  }

  Map<String, dynamic> _buildProgressData() => {'qIndex': _qIndex};

  Future<void> _handleReturnPressed() async {
    await ActivityExitHandler.handleExitActivity(
      context: context,
      activityId: _activityId,
      activityName: 'EMOMATCH',
      activityEmoji: '🌟',
      buildProgressData: _buildProgressData,
      starGameKey: StarService.emoMatch,
      sessionStars: _sessionStars,
      elapsedSeconds: _stopwatch.elapsed.inSeconds,
    );
  }

  // ── Game logic ────────────────────────────────────────────────────────────

  void _onOptionTap(int index) {
    if (_answered) return;

    final isCorrect = index == _correctIdx;

    // ── Hint mode: only the correct (glowing) card is tappable ──
    if (_revealAnswer) {
      if (!isCorrect) return; // ignore taps on wrong cards
      _hintController.stop();
      _advanceCorrect();
      return;
    }

    setState(() => _tappedIdx = index);

    if (isCorrect) {
      _advanceCorrect();
    } else {
      // ── Wrong ──
      _attempts++;
      AudioService.instance.playSfx(SoundEffect.wrong);
      setState(() => _flashRed[index] = true);
      _shakeController.forward(from: 0);

      if (_attempts >= 2) {
        // Show hint: highlight correct card, let child tap it
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          setState(() {
            _revealAnswer = true;
            _tappedIdx = null;
            _flashRed[index] = false;
          });
          _hintController.repeat(reverse: true);
        });
      } else {
        // Allow retry
        Future.delayed(const Duration(milliseconds: 700), () {
          if (!mounted) return;
          setState(() {
            _tappedIdx = null;
            _flashRed[index] = false;
          });
        });
      }
    }
  }

  void _advanceCorrect() {
    setState(() => _answered = true);
    AudioService.instance.playSfx(SoundEffect.correct);
    _correctPulseController.forward(from: 0);
    _sessionStars++;
    EmotionJournalService.log(
      emoji: _currentQ.emoji,
      emotionName: _currentQ.label,
      category: 'daily_routine',
      gameId: _activityId,
    );
    StarRewardWidget.show(context);
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      _qIndex++;
      if (_qIndex >= _shuffled.length) {
        _shuffled = List.of(_bank)..shuffle(_rng);
        _qIndex = 0;
      }
      setState(() => _loadQuestion());
    });
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  TextStyle _cute({
    double sz = 24,
    Color c = Colors.white,
    FontWeight fw = FontWeight.w700,
  }) =>
      GoogleFonts.baloo2(fontSize: sz, fontWeight: fw, color: c);

  // Distinct per-position colors to help visual discrimination
  static const List<Color> _optBg = [
    Color(0xFFFFF9C4), // soft yellow
    Color(0xFFE1F5FE), // soft sky-blue
    Color(0xFFF3E5F5), // soft lavender
    Color(0xFFE8F5E9), // soft mint-green
  ];
  static const List<Color> _optBorder = [
    Color(0xFFF9A825), // amber
    Color(0xFF039BE5), // blue
    Color(0xFF8E24AA), // purple
    Color(0xFF43A047), // green
  ];

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final q = _currentQ;

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
                Color(0xFFFFF0F5), // rose-white
                Color(0xFFF3E8FF), // soft lavender
                Color(0xFFEEF2FF), // indigo tint
              ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // ── Main layout ───────────────────────────────────────
                Column(
                  children: [
                    const SizedBox(height: 56),

                    // Question card
                    Center(
                      child: ScaleTransition(
                        scale: _enterAnim,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 680),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 36),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(36),
                            border: Border.all(
                              color: const Color(0xFF7C3AED)
                                  .withValues(alpha: 0.35),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6B21A8)
                                    .withValues(alpha: 0.12),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(q.emoji,
                                  style: const TextStyle(fontSize: 90)),
                              const SizedBox(width: 20),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    q.label,
                                    style: _cute(
                                      sz: 42,
                                      fw: FontWeight.w900,
                                      c: const Color(0xFF1F2937),
                                    ),
                                  ),
                                  Text(
                                    'What goes with this?',
                                    style: _cute(
                                        sz: 22, c: const Color(0xFF6B7280)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Hint prompt after 2 wrong attempts
                    if (_revealAnswer)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '💡 Tap the glowing one!',
                          style: _cute(sz: 22, c: const Color(0xFF22C55E)),
                        ),
                      ),

                    // 2×2 option grid — fills remaining space
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(40, 0, 40, 9),
                        child: AnimatedBuilder(
                          animation: _shakeController,
                          builder: (ctx, child) {
                            final shake = _shakeController.isAnimating
                                ? sin(_shakeController.value * 3 * pi) * 9.0
                                : 0.0;
                            return Transform.translate(
                              offset: Offset(shake, 0),
                              child: child,
                            );
                          },
                          child: Column(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(child: _buildOption(0)),
                                    const SizedBox(width: 20),
                                    Expanded(child: _buildOption(1)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(child: _buildOption(2)),
                                    const SizedBox(width: 20),
                                    Expanded(child: _buildOption(3)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Top bar ───────────────────────────────────────────

                // Help + Star pill
                Positioned(
                  top: 14,
                  right: 16,
                  child: Row(
                    children: [
                      HelpButton(
                        activityId: _activityId,
                        activityEmoji: '🌟',
                        activityName: 'EMOMATCH',
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 19, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B21A8),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Text('⭐ $_sessionStars', style: _cute(sz: 26)),
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
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Color(0xFF6B21A8),
                        size: 30,
                      ),
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

  // ── Option card ───────────────────────────────────────────────────────────

  Widget _buildOption(int i) {
    final opt = _options[i];
    final isCorrect = i == _correctIdx;

    // Determine visual state
    Color bg, borderColor, labelColor;
    double borderWidth = 2.5;
    List<BoxShadow> shadows = [];

    if (_answered && isCorrect) {
      // Correct answer chosen
      bg = const Color(0xFFDCFCE7);
      borderColor = const Color(0xFF22C55E);
      borderWidth = 4.5;
      labelColor = const Color(0xFF166534);
      shadows = [
        BoxShadow(
          color: const Color(0xFF22C55E).withValues(alpha: 0.45),
          blurRadius: 22,
          spreadRadius: 3,
        ),
      ];
    } else if (_answered) {
      // Other options — fade out
      bg = Colors.white.withValues(alpha: 0.35);
      borderColor = Colors.grey.shade200;
      labelColor = Colors.grey.shade400;
    } else if (_revealAnswer && isCorrect) {
      // Reveal after 2 fails — highlight correct in green
      bg = const Color(0xFFDCFCE7);
      borderColor = const Color(0xFF22C55E);
      borderWidth = 4.5;
      labelColor = const Color(0xFF166534);
      shadows = [
        BoxShadow(
          color: const Color(0xFF22C55E).withValues(alpha: 0.45),
          blurRadius: 22,
          spreadRadius: 3,
        ),
      ];
    } else if (_revealAnswer) {
      // Other options during reveal — dim
      bg = Colors.white.withValues(alpha: 0.3);
      borderColor = Colors.grey.shade200;
      labelColor = Colors.grey.shade400;
    } else if (_flashRed[i]) {
      // Wrong tap flash
      bg = const Color(0xFFFEE2E2);
      borderColor = const Color(0xFFEF4444);
      borderWidth = 3.5;
      labelColor = const Color(0xFF991B1B);
      shadows = [
        BoxShadow(
          color: const Color(0xFFEF4444).withValues(alpha: 0.35),
          blurRadius: 16,
          spreadRadius: 2,
        ),
      ];
    } else {
      // Normal / idle — distinct per-position pastels
      bg = _optBg[i];
      borderColor = _optBorder[i];
      labelColor = const Color(0xFF1F2937);
      if (_tappedIdx == i) {
        borderWidth = 3.5;
        shadows = [
          BoxShadow(
            color: _optBorder[i].withValues(alpha: 0.35),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ];
      }
    }

    Widget card = GestureDetector(
      onTap: () => _onOptionTap(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 190),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: shadows,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              opt.emoji,
              style: const TextStyle(
                fontSize: 92,
                fontFamilyFallback: [
                  'Segoe UI Emoji',
                  'Apple Color Emoji',
                  'Noto Color Emoji',
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              opt.label,
              style: _cute(sz: 35, fw: FontWeight.w800, c: labelColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    // Scale pulse on correct answer
    if (_answered && isCorrect) {
      card = ScaleTransition(scale: _correctPulseAnim, child: card);
    }
    // Looping glow-pulse hint after 2 errors — child must tap it
    if (_revealAnswer && isCorrect) {
      card = AnimatedBuilder(
        animation: _hintController,
        builder: (_, ch) {
          final t = _hintController.value; // 0→1→0 (reverse repeat)
          return Transform.scale(
            scale: 1.0 + t * 0.07,
            child: ch,
          );
        },
        child: card,
      );
    }

    return card;
  }
}
