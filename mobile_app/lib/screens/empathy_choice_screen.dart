import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/star_service.dart';
import '../core/widgets/star_reward_widget.dart';
import '../features/child/presentation/help_button.dart';
import '../features/child/presentation/activity_exit_handler.dart';
import '../features/child/presentation/completion_feedback_overlay.dart';

/// Empathy Quest — Children see an emotional scenario and choose
/// the most kind/helpful response from visual options.
class EmpathyChoiceScreen extends StatefulWidget {
  const EmpathyChoiceScreen({super.key});

  @override
  State<EmpathyChoiceScreen> createState() => _EmpathyChoiceScreenState();
}

class _Scenario {
  final String emoji;
  final String situation;
  final List<_Choice> choices;
  const _Scenario({required this.emoji, required this.situation, required this.choices});
}

class _Choice {
  final String emoji;
  final String text;
  final bool isKind;
  const _Choice({required this.emoji, required this.text, required this.isKind});
}

class _EmpathyChoiceScreenState extends State<EmpathyChoiceScreen> {
  static const List<_Scenario> _allScenarios = [
    _Scenario(
      emoji: '😢',
      situation: 'Your friend is crying because they lost their toy.',
      choices: [
        _Choice(emoji: '🤗', text: 'Give them a hug', isKind: true),
        _Choice(emoji: '🚶', text: 'Walk away', isKind: false),
        _Choice(emoji: '🔍', text: 'Help them look for it', isKind: true),
      ],
    ),
    _Scenario(
      emoji: '😞',
      situation: 'Someone is sitting alone at lunch.',
      choices: [
        _Choice(emoji: '👋', text: 'Ask them to join you', isKind: true),
        _Choice(emoji: '😶', text: 'Ignore them', isKind: false),
        _Choice(emoji: '😊', text: 'Smile and say hi', isKind: true),
      ],
    ),
    _Scenario(
      emoji: '😨',
      situation: 'A younger child is scared of the dark.',
      choices: [
        _Choice(emoji: '😂', text: 'Laugh at them', isKind: false),
        _Choice(emoji: '🤝', text: 'Hold their hand', isKind: true),
        _Choice(emoji: '💡', text: 'Turn on a light for them', isKind: true),
      ],
    ),
    _Scenario(
      emoji: '😡',
      situation: 'Your sibling is angry because you took their crayon.',
      choices: [
        _Choice(emoji: '🙏', text: 'Say sorry and return it', isKind: true),
        _Choice(emoji: '😤', text: 'Keep it anyway', isKind: false),
        _Choice(emoji: '🤝', text: 'Share with them', isKind: true),
      ],
    ),
    _Scenario(
      emoji: '🤕',
      situation: 'A classmate fell down and scraped their knee.',
      choices: [
        _Choice(emoji: '🏃', text: 'Get a teacher to help', isKind: true),
        _Choice(emoji: '👀', text: 'Just watch', isKind: false),
        _Choice(emoji: '💛', text: 'Ask if they are okay', isKind: true),
      ],
    ),
    _Scenario(
      emoji: '😰',
      situation: 'Your friend is nervous about a test.',
      choices: [
        _Choice(emoji: '💪', text: 'Say "You can do it!"', isKind: true),
        _Choice(emoji: '🤷', text: 'Say "It\'s easy for me"', isKind: false),
        _Choice(emoji: '📚', text: 'Help them study', isKind: true),
      ],
    ),
    _Scenario(
      emoji: '🥺',
      situation: 'A new student doesn\'t know anyone at school.',
      choices: [
        _Choice(emoji: '🤗', text: 'Introduce yourself', isKind: true),
        _Choice(emoji: '🙄', text: 'Pretend not to see them', isKind: false),
        _Choice(emoji: '🎮', text: 'Invite them to play', isKind: true),
      ],
    ),
    _Scenario(
      emoji: '😭',
      situation: 'Your little brother can\'t reach his favourite book.',
      choices: [
        _Choice(emoji: '📖', text: 'Get it for him', isKind: true),
        _Choice(emoji: '😏', text: 'Say "Too bad!"', isKind: false),
        _Choice(emoji: '🪜', text: 'Help him climb safely', isKind: true),
      ],
    ),
    _Scenario(
      emoji: '😔',
      situation: 'Someone dropped all their papers on the floor.',
      choices: [
        _Choice(emoji: '🤲', text: 'Help pick them up', isKind: true),
        _Choice(emoji: '👣', text: 'Step over and keep walking', isKind: false),
        _Choice(emoji: '😊', text: 'Say "Let me help!"', isKind: true),
      ],
    ),
    _Scenario(
      emoji: '😿',
      situation: 'Your friend\'s pet is sick.',
      choices: [
        _Choice(emoji: '🫂', text: 'Comfort your friend', isKind: true),
        _Choice(emoji: '🤷', text: 'Say "It\'s just a pet"', isKind: false),
        _Choice(emoji: '💌', text: 'Make a get-well card', isKind: true),
      ],
    ),
  ];

  final Random _rng = Random();
  late List<_Scenario> _shuffledScenarios;

  int _currentIndex = 0;
  int _stars = 0;
  int? _selectedChoice;
  bool _showResult = false;
  bool _answeredCorrectly = false;

  @override
  void initState() {
    super.initState();
    _shuffledScenarios = List.from(_allScenarios)..shuffle(_rng);
  }

  void _onChoiceTap(int choiceIndex) {
    if (_showResult) return;
    final choice = _shuffledScenarios[_currentIndex].choices[choiceIndex];

    setState(() {
      _selectedChoice = choiceIndex;
      _showResult = true;
      _answeredCorrectly = choice.isKind;
    });

    if (choice.isKind) {
      StarService.addStars(StarService.emotionSignals, 1);
      _stars++;
    }

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      if (_currentIndex + 1 >= _shuffledScenarios.length) {
        CompletionFeedbackOverlay.show(
          context: context,
          activityId: 'game_empathy_choice',
          activityName: 'Empathy Quest',
          starGameKey: StarService.emotionSignals,
          starsEarned: 3,
          scoreValue: _stars,
          scoreMax: _shuffledScenarios.length,
          onPlayAgain: () {
            setState(() {
              _currentIndex = 0;
              _stars = 0;
              _shuffledScenarios.shuffle(_rng);
            });
          },
        );
      } else {
        if (choice.isKind) StarRewardWidget.show(context);
        setState(() {
          _currentIndex++;
          _selectedChoice = null;
          _showResult = false;
        });
      }
    });
  }

  TextStyle _cute(
          {double sz = 24,
          Color c = Colors.white,
          FontWeight fw = FontWeight.w700}) =>
      GoogleFonts.baloo2(fontSize: sz, fontWeight: fw, color: c);

  @override
  Widget build(BuildContext context) {
    final scenario = _shuffledScenarios[_currentIndex];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE), Color(0xFFC7D2FE)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  const SizedBox(height: 80),
                  // Progress
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: (_currentIndex + (_showResult ? 1 : 0)) / _shuffledScenarios.length,
                        minHeight: 12,
                        backgroundColor: Colors.white54,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5D9CEC)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Big scenario emoji
                  Text(scenario.emoji, style: const TextStyle(fontSize: 100)),
                  const SizedBox(height: 12),
                  // Situation text
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        scenario.situation,
                        textAlign: TextAlign.center,
                        style: _cute(sz: 20, fw: FontWeight.w600, c: Colors.black87),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Choices
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: List.generate(scenario.choices.length, (i) {
                          return _buildChoiceCard(scenario.choices[i], i);
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
              // Back button
              Positioned(
                top: 10,
                left: 10,
                child: GestureDetector(
                  onTap: () => ActivityExitHandler.handleExitActivity(
                    context: context,
                    activityId: 'game_empathy_choice',
                    activityEmoji: '💛',
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
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
                        color: Color(0xFF5D9CEC), size: 32),
                  ),
                ),
              ),
              // Banner
              Positioned(
                top: 14,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 26),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: const Color(0xFF5D9CEC).withValues(alpha: 0.5),
                        width: 3,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('💛 What would you do?  ',
                            style: _cute(sz: 22, fw: FontWeight.w900, c: Colors.black87)),
                        Text('${_currentIndex + 1}/${_shuffledScenarios.length}',
                            style: _cute(sz: 20, c: const Color(0xFF5D9CEC))),
                      ],
                    ),
                  ),
                ),
              ),
              // Hint + Stars
              Positioned(
                top: 14,
                right: 16,
                child: Row(
                  children: [
                    const HelpButton(
                      activityId: 'game_empathy_choice',
                      activityEmoji: '💛',
                      activityName: 'Empathy Quest',
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5D9CEC),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text('⭐ $_stars', style: _cute(sz: 22)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceCard(_Choice choice, int index) {
    final isSelected = _selectedChoice == index;
    final showingResult = _showResult;

    Color cardColor;
    Color borderColor;
    if (showingResult && isSelected) {
      cardColor = choice.isKind ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
      borderColor = choice.isKind ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    } else if (showingResult && choice.isKind) {
      // Highlight correct answers when result is shown
      cardColor = const Color(0xFFF0FFF4);
      borderColor = const Color(0xFF22C55E).withValues(alpha: 0.4);
    } else {
      cardColor = Colors.white;
      borderColor = const Color(0xFF5D9CEC).withValues(alpha: 0.3);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: _showResult ? null : () => _onChoiceTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 3.5 : 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? borderColor.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: isSelected ? 12 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(choice.emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  choice.text,
                  style: _cute(
                    sz: 20,
                    fw: FontWeight.w700,
                    c: showingResult && isSelected
                        ? (choice.isKind ? const Color(0xFF16A34A) : const Color(0xFFDC2626))
                        : const Color(0xFF1E293B),
                  ),
                ),
              ),
              if (showingResult && isSelected)
                Icon(
                  choice.isKind ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: choice.isKind ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                  size: 32,
                ),
              if (showingResult && !isSelected && choice.isKind)
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: const Color(0xFF22C55E).withValues(alpha: 0.5),
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
