import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/data/game_emojis.dart';
import '../core/services/star_service.dart';
import '../core/widgets/star_reward_widget.dart';
import '../features/child/presentation/help_button.dart';
import '../features/child/presentation/activity_exit_handler.dart';
import '../features/child/services/activity_progress_service.dart';

/// Emoji Spell — A spelling game where children see an emoji and
/// tap scrambled letters to spell the emotion name.
class EmojiSpellingScreen extends StatefulWidget {
  const EmojiSpellingScreen({super.key});

  @override
  State<EmojiSpellingScreen> createState() => _EmojiSpellingScreenState();
}

class _EmojiSpellingScreenState extends State<EmojiSpellingScreen>
    with TickerProviderStateMixin {
  static final List<Map<String, String>> _allEmojis =
      GameEmojis.all.map((e) => {'emoji': e.emoji, 'word': e.word, 'category': e.category}).toList();

  static const String _activityId = 'game_emoji_spell';
  final ActivityProgressService _progressService = ActivityProgressService();

  final Random _rng = Random();

  /// Returns emojis ordered: feelings first (shuffled), then rest (shuffled).
  List<Map<String, String>> _buildFeelingsFirst() {
    final feelings = _allEmojis.where((e) => e['category'] == 'feelings').toList()..shuffle(_rng);
    final rest = _allEmojis.where((e) => e['category'] != 'feelings').toList()..shuffle(_rng);
    return [...feelings, ...rest];
  }

  late List<Map<String, String>> _shuffledEmojis;

  int _currentIndex = 0;
  int _sessionStars = 0;
  String _currentWord = '';
  String _currentEmoji = '';
  List<String> _scrambledLetters = [];
  List<bool> _letterUsed = [];
  String _typedSoFar = '';
  bool _showCorrect = false;
  bool _showWrong = false;

  late AnimationController _bounceController;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shuffledEmojis = _buildFeelingsFirst();
    _loadWord();
    _restoreProgress();
  }

  Future<void> _restoreProgress() async {
    final saved = await _progressService.loadProgress(_activityId);
    if (!mounted || saved == null) return;
    final data = saved.progressData;
    final savedIndex = data['currentIndex'];
    final savedWordOrder = data['wordOrder'];
    if (savedIndex is! int || savedWordOrder is! List) return;
    final wordList = savedWordOrder.whereType<String>().toList();
    if (wordList.isEmpty) return;
    final restored = wordList
        .map((w) => _allEmojis.firstWhere(
              (e) => e['word'] == w,
              orElse: () => <String, String>{},
            ))
        .where((e) => e.isNotEmpty)
        .toList();
    if (restored.isEmpty) return;
    final clampedIndex = savedIndex.clamp(0, restored.length - 1);

    // Resume at saved level, restart word fresh (no mid-word state)
    setState(() {
      _shuffledEmojis = restored;
      _currentIndex = clampedIndex;
      _sessionStars = 0; // always start session at 0
    });
    _loadWord();
  }

  Map<String, dynamic> _buildProgressData() => {
        'currentIndex': _currentIndex,
        'wordOrder': _shuffledEmojis.map((e) => e['word'] as String).toList(),
      };

  Future<void> _handleReturnPressed() async {
    await ActivityExitHandler.handleExitActivity(
      context: context,
      activityId: _activityId,
      activityEmoji: '🔤',
      buildProgressData: _buildProgressData,
      starGameKey: StarService.emojiSpell,
      sessionStars: _sessionStars,
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _loadWord() {
    final entry = _shuffledEmojis[_currentIndex];
    _currentWord = entry['word']!;
    _currentEmoji = entry['emoji']!;
    _typedSoFar = '';
    _showCorrect = false;
    _showWrong = false;

    // Create scrambled letters: all correct letters + some random extras
    final letters = _currentWord.split('');
    // Add 2-4 random distractor letters
    final distractorCount = 2 + _rng.nextInt(3);
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    for (int i = 0; i < distractorCount; i++) {
      letters.add(alphabet[_rng.nextInt(26)]);
    }
    letters.shuffle(_rng);
    _scrambledLetters = letters;
    _letterUsed = List.filled(_scrambledLetters.length, false);
    setState(() {});
  }

  void _onLetterTap(int index) {
    if (_letterUsed[index] || _showCorrect) return;

    final tappedLetter = _scrambledLetters[index];
    final expectedLetter = _currentWord[_typedSoFar.length];

    if (tappedLetter == expectedLetter) {
      setState(() {
        _typedSoFar += tappedLetter;
        _letterUsed[index] = true;
      });

      // Check if word is complete
      if (_typedSoFar == _currentWord) {
        _onWordComplete();
      }
    } else {
      // Wrong letter — shake
      setState(() => _showWrong = true);
      _shakeController.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _showWrong = false);
      });
    }
  }

  void _onWordComplete() {
    setState(() => _showCorrect = true);
    _bounceController.forward(from: 0);

    _sessionStars++;

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      StarRewardWidget.show(context);
      if (_currentIndex + 1 >= _shuffledEmojis.length) {
        // All 48 done — reshuffle feelings-first and start over
        setState(() {
          _currentIndex = 0;
          _shuffledEmojis = _buildFeelingsFirst();
        });
      } else {
        setState(() => _currentIndex++);
      }
      _loadWord();
    });
  }

  void _undoLast() {
    if (_typedSoFar.isEmpty || _showCorrect) return;
    final lastChar = _typedSoFar[_typedSoFar.length - 1];
    // Find the last used letter matching this char
    for (int i = _letterUsed.length - 1; i >= 0; i--) {
      if (_letterUsed[i] && _scrambledLetters[i] == lastChar) {
        setState(() {
          _letterUsed[i] = false;
          _typedSoFar = _typedSoFar.substring(0, _typedSoFar.length - 1);
        });
        break;
      }
    }
  }

  TextStyle _cute(
          {double sz = 24,
          Color c = Colors.white,
          FontWeight fw = FontWeight.w700}) =>
      GoogleFonts.baloo2(fontSize: sz, fontWeight: fw, color: c);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _handleReturnPressed();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFF1E6), Color(0xFFFFE0F0), Color(0xFFE8F5E9)],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    // Space reserved for the top header row
                    const SizedBox(height: 90),
                    // Vertically centered game content
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Big emoji
                              Text(_currentEmoji,
                                  style: const TextStyle(fontSize: 175)),
                              const SizedBox(height: 20),
                              // Word slots
                              _buildWordSlots(),
                              const SizedBox(height: 36),
                              // Scrambled letter tiles
                              _buildLetterTiles(),
                              const SizedBox(height: 20),
                              // Undo button
                              if (_typedSoFar.isNotEmpty && !_showCorrect)
                                TextButton.icon(
                                  onPressed: _undoLast,
                                  icon: const Icon(Icons.undo_rounded,
                                      color: Color(0xFF6366F1)),
                                  label: Text('Undo',
                                      style: _cute(
                                          sz: 18, c: const Color(0xFF6366F1))),
                                ),
                              // Feedback
                              if (_showCorrect)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Text('✨ Correct! ✨',
                                      style: _cute(
                                          sz: 34,
                                          fw: FontWeight.w900,
                                          c: const Color(0xFF22C55E))),
                                ),
                              if (_showWrong)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Text('Try another letter!',
                                      style: _cute(
                                          sz: 22, c: const Color(0xFFEF4444))),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Back button — same style as Bubble Pop
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
                // Target banner — enlarged to match Bubble Pop
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 30),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(34),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.6),
                          width: 3,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🔤 Spell it!',
                              style: _cute(
                                  sz: 31,
                                  fw: FontWeight.w900,
                                  c: Colors.black87)),
                        ],
                      ),
                    ),
                  ),
                ),
                // Hint + Score — enlarged to match Bubble Pop
                Positioned(
                  top: 20,
                  right: 20,
                  child: Row(
                    children: [
                      const HelpButton(
                        activityId: 'game_emoji_spell',
                        activityEmoji: '🔤',
                        activityName: 'EMOSPELL',
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 19, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Text('⭐ $_sessionStars', style: _cute(sz: 26)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  } // end build

  Widget _buildWordSlots() {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final shake =
            _showWrong ? sin(_shakeController.value * 3 * pi) * 8 : 0.0;
        return Transform.translate(offset: Offset(shake, 0), child: child);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_currentWord.length, (i) {
          final filled = i < _typedSoFar.length;
          final isNext = i == _typedSoFar.length && !_showCorrect;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: 78,
            height: 88,
            decoration: BoxDecoration(
              color: filled
                  ? (_showCorrect
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF6366F1))
                  : isNext
                      ? const Color(0xFFEEF2FF)
                      : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: filled
                    ? Colors.transparent
                    : isNext
                        ? const Color(0xFF6366F1)
                        : const Color(0xFF6366F1).withValues(alpha: 0.3),
                width: isNext ? 3.5 : 2.5,
              ),
              boxShadow: filled
                  ? [
                      BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3))
                    ]
                  : isNext
                      ? [
                          BoxShadow(
                              color: const Color(0xFF6366F1)
                                  .withValues(alpha: 0.2),
                              blurRadius: 10)
                        ]
                      : [],
            ),
            child: Center(
              child: Text(
                filled
                    ? _typedSoFar[i]
                    : isNext
                        ? '?'
                        : '',
                style: _cute(
                    sz: 45,
                    fw: FontWeight.w900,
                    c: filled
                        ? Colors.white
                        : const Color(0xFF6366F1).withValues(alpha: 0.3)),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLetterTiles() {
    // Determine the next expected letter for highlighting
    final String? expectedLetter = _typedSoFar.length < _currentWord.length
        ? _currentWord[_typedSoFar.length]
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        alignment: WrapAlignment.center,
        children: List.generate(_scrambledLetters.length, (i) {
          final used = _letterUsed[i];
          final letter = _scrambledLetters[i];
          final isCorrectLetter =
              !used && expectedLetter != null && letter == expectedLetter;
          return GestureDetector(
            onTap: used ? null : () => _onLetterTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 95,
              height: 95,
              decoration: BoxDecoration(
                color: used
                    ? Colors.grey.shade200
                    : isCorrectLetter
                        ? const Color(0xFFF0FFF4)
                        : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: used
                      ? Colors.grey.shade300
                      : isCorrectLetter
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFFF9F43),
                  width: isCorrectLetter ? 3.5 : 2.5,
                ),
                boxShadow: used
                    ? []
                    : isCorrectLetter
                        ? [
                            BoxShadow(
                                color: const Color(0xFF22C55E)
                                    .withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 2))
                          ]
                        : [
                            BoxShadow(
                                color: const Color(0xFFFF9F43)
                                    .withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3))
                          ],
              ),
              child: Center(
                child: Text(
                  letter,
                  style: _cute(
                    sz: 45,
                    fw: FontWeight.w900,
                    c: used
                        ? Colors.grey.shade400
                        : isCorrectLetter
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF1B2541),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
