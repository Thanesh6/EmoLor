import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../features/child/presentation/help_button.dart';
import '../features/child/presentation/activity_exit_handler.dart';
import '../features/child/presentation/completion_feedback_overlay.dart';
import '../core/services/star_service.dart';

class StoriesScreen extends StatefulWidget {
  const StoriesScreen({super.key});

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;

  final List<Map<String, dynamic>> _stories = [
    {
      'title': 'The Happy Cloud',
      'emoji': '☁️',
      'color': const Color(0xFF87CEEB),
    },
    {
      'title': 'Brave Little Bear',
      'emoji': '🐻',
      'color': const Color(0xFFDEB887),
    },
    {
      'title': 'Rainbow Friends',
      'emoji': '🌈',
      'color': const Color(0xFFFF6B6B),
    },
  ];

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  TextStyle _cuteTextStyle({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w700,
    Color color = Colors.white,
    List<Shadow>? shadows,
  }) {
    return GoogleFonts.baloo2(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      shadows: shadows,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF1EB),
              Color(0xFFACE0F9),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Title
                  Padding(
                    padding: const EdgeInsets.all(25),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                            width: 50), // Reserve space for back button
                        Text(
                          'Story Time!',
                          style: _cuteTextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF6B21A8),
                            shadows: const [
                              Shadow(
                                  offset: Offset(3, 3),
                                  blurRadius: 6,
                                  color: Colors.black26),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),
                        const Text('✨', style: TextStyle(fontSize: 55)),
                        const SizedBox(width: 50), // Balance spacing
                      ],
                    ),
                  ),

                  // Subtitle
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      '👆 Pick a story to begin! 👆',
                      style: _cuteTextStyle(
                        fontSize: 28,
                        color: const Color(0xFF6B21A8),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Story Selection
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _stories.asMap().entries.map((entry) {
                        final index = entry.key;
                        final story = entry.value;
                        return AnimatedBuilder(
                          animation: _bounceController,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(
                                  0,
                                  -8 *
                                      _bounceController.value *
                                      (index % 2 == 0 ? 1 : -1)),
                              child: child,
                            );
                          },
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => InteractiveStoryPage(
                                    storyIndex: index,
                                    story: story,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 280,
                              height: 350,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    story['color'],
                                    story['color'].withValues(alpha: 0.7)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(40),
                                border:
                                    Border.all(color: Colors.white, width: 6),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        story['color'].withValues(alpha: 0.5),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(story['emoji'],
                                      style: const TextStyle(fontSize: 90)),
                                  const SizedBox(height: 20),
                                  Text(
                                    story['title'],
                                    style: _cuteTextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      shadows: const [
                                        Shadow(
                                            offset: Offset(2, 2),
                                            blurRadius: 4,
                                            color: Colors.black38),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 15),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 25, vertical: 10),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '▶️ START',
                                      style: _cuteTextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              // Back button (consistent with other activity screens)
              Positioned(
                top: 20,
                left: 20,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Color(0xFF6B21A8),
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Interactive Story Page with choices
class InteractiveStoryPage extends StatefulWidget {
  final int storyIndex;
  final Map<String, dynamic> story;

  const InteractiveStoryPage({
    super.key,
    required this.storyIndex,
    required this.story,
  });

  @override
  State<InteractiveStoryPage> createState() => _InteractiveStoryPageState();
}

class _InteractiveStoryPageState extends State<InteractiveStoryPage>
    with TickerProviderStateMixin {
  int _currentPage = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String? _selectedChoice;

  // Story data with pages and choices
  late List<Map<String, dynamic>> _storyPages;

  // UCD015: Map storyIndex → activity id for the Help button.
  static const _storyActivityIds = [
    'story_happy_cloud',
    'story_brave_bear',
    'story_rainbow_friends',
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _fadeController.forward();

    // Initialize story pages based on story index
    _initStoryPages();
  }

  void _initStoryPages() {
    if (widget.storyIndex == 0) {
      // The Happy Cloud
      _storyPages = [
        {
          'text':
              'Once upon a time, there was a little cloud named Fluffy. ☁️\n\nFluffy was feeling sad today...',
          'emoji': '☁️😢',
          'question': 'Why do you think Fluffy is sad?',
          'choices': [
            {
              'text': 'Fluffy is lonely',
              'emoji': '😔',
              'color': const Color(0xFF87CEEB)
            },
            {
              'text': 'Fluffy lost a friend',
              'emoji': '💔',
              'color': const Color(0xFFFF6B6B)
            },
            {
              'text': 'Fluffy feels different',
              'emoji': '🤔',
              'color': const Color(0xFFBB6BD9)
            },
          ],
        },
        {
          'text':
              'Fluffy met a kind sun named Sunny! ☀️\n\nSunny asked: "What makes you happy?"',
          'emoji': '☀️☁️',
          'question': 'What should Fluffy say?',
          'choices': [
            {
              'text': 'Playing with rain! 🌧️',
              'emoji': '🌧️',
              'color': const Color(0xFF4ECDC4)
            },
            {
              'text': 'Making rainbows! 🌈',
              'emoji': '🌈',
              'color': const Color(0xFFFFE66D)
            },
            {
              'text': 'Floating with friends! 💨',
              'emoji': '💨',
              'color': const Color(0xFF7ED957)
            },
          ],
        },
        {
          'text':
              'Fluffy learned that it\'s okay to feel different emotions!\n\n"Every feeling is like a different color in the rainbow!" 🌈',
          'emoji': '☁️😊🌈',
          'question': 'How do YOU feel right now?',
          'choices': [
            {'text': 'Happy!', 'emoji': '😊', 'color': const Color(0xFFFFE66D)},
            {'text': 'Calm', 'emoji': '😌', 'color': const Color(0xFF4ECDC4)},
            {
              'text': 'Excited!',
              'emoji': '🤩',
              'color': const Color(0xFFFF6B6B)
            },
          ],
          'isEnding': true,
        },
      ];
    } else if (widget.storyIndex == 1) {
      // Brave Little Bear
      _storyPages = [
        {
          'text':
              'In a cozy forest lived a little bear named Teddy. 🐻\n\nTeddy was scared of something...',
          'emoji': '🐻😰',
          'question': 'What is Teddy scared of?',
          'choices': [
            {
              'text': 'The dark forest',
              'emoji': '🌲🌑',
              'color': const Color(0xFF2C3E50)
            },
            {
              'text': 'Thunder sounds',
              'emoji': '⛈️',
              'color': const Color(0xFF6B7280)
            },
            {
              'text': 'Meeting new animals',
              'emoji': '🦊',
              'color': const Color(0xFFFF9F43)
            },
          ],
        },
        {
          'text':
              'Teddy\'s friend Bunny 🐰 was stuck!\n\n"Help me Teddy!" cried Bunny.',
          'emoji': '🐰😟',
          'question': 'Should Teddy be brave?',
          'choices': [
            {
              'text': 'Yes! Help Bunny! 💪',
              'emoji': '💪',
              'color': const Color(0xFF10B981)
            },
            {
              'text': 'Take a deep breath first 🧘',
              'emoji': '🧘',
              'color': const Color(0xFF4ECDC4)
            },
            {
              'text': 'Call for more help! 📢',
              'emoji': '📢',
              'color': const Color(0xFFFFE66D)
            },
          ],
        },
        {
          'text':
              'Teddy did it! Teddy saved Bunny! 🎉\n\n"Being brave doesn\'t mean not being scared. It means doing the right thing even when scared!"',
          'emoji': '🐻🐰💕',
          'question': 'Have you been brave before?',
          'choices': [
            {
              'text': 'Yes, I\'m brave!',
              'emoji': '🦸',
              'color': const Color(0xFFFF6B6B)
            },
            {
              'text': 'I want to be brave!',
              'emoji': '⭐',
              'color': const Color(0xFFFFE66D)
            },
            {
              'text': 'I can try!',
              'emoji': '💫',
              'color': const Color(0xFFBB6BD9)
            },
          ],
          'isEnding': true,
        },
      ];
    } else {
      // Rainbow Friends
      _storyPages = [
        {
          'text':
              'There were 7 color friends living in the sky! 🌈\n\nBut they were arguing...',
          'emoji': '🔴🟠🟡🟢🔵🟣',
          'question': 'What were they arguing about?',
          'choices': [
            {
              'text': 'Who is the prettiest?',
              'emoji': '👑',
              'color': const Color(0xFFFFE66D)
            },
            {
              'text': 'Who is the strongest?',
              'emoji': '💪',
              'color': const Color(0xFFFF6B6B)
            },
            {
              'text': 'Who is the most important?',
              'emoji': '⭐',
              'color': const Color(0xFF4ECDC4)
            },
          ],
        },
        {
          'text':
              'A little girl looked up at the sky. 👧\n\n"I wish I could see a rainbow!"',
          'emoji': '👧✨',
          'question': 'What should the colors do?',
          'choices': [
            {
              'text': 'Work together! 🤝',
              'emoji': '🤝',
              'color': const Color(0xFF10B981)
            },
            {
              'text': 'Share the sky! 🌤️',
              'emoji': '🌤️',
              'color': const Color(0xFF87CEEB)
            },
            {
              'text': 'Make her smile! 😊',
              'emoji': '😊',
              'color': const Color(0xFFFFE66D)
            },
          ],
        },
        {
          'text':
              'The colors joined together and made a beautiful RAINBOW! 🌈\n\n"Together we are MORE beautiful!"',
          'emoji': '🌈✨🎉',
          'question': 'What did you learn?',
          'choices': [
            {
              'text': 'Teamwork is great!',
              'emoji': '🤝',
              'color': const Color(0xFF10B981)
            },
            {
              'text': 'Everyone is special!',
              'emoji': '⭐',
              'color': const Color(0xFFFFE66D)
            },
            {
              'text': 'Together we shine!',
              'emoji': '✨',
              'color': const Color(0xFFBB6BD9)
            },
          ],
          'isEnding': true,
        },
      ];
    }
  }

  void _nextPage(String choice) {
    setState(() {
      _selectedChoice = choice;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (_currentPage < _storyPages.length - 1) {
        _fadeController.reverse().then((_) {
          setState(() {
            _currentPage++;
            _selectedChoice = null;
          });
          _fadeController.forward();
        });
      } else {
        // Story finished
        _showEndingDialog();
      }
    });
  }

  void _showEndingDialog() {
    // UCD018 — show completion feedback overlay.
    final activityId = widget.storyIndex < _storyActivityIds.length
        ? _storyActivityIds[widget.storyIndex]
        : 'story_unknown';

    CompletionFeedbackOverlay.show(
      context: context,
      activityId: activityId,
      activityName: widget.story['title'] ?? 'Story',
      starGameKey: StarService.stories,
      starsEarned: 1, // completion star
      onPlayAgain: () {
        // Go back to story list so child can pick another story.
        Navigator.pop(context);
      },
    );
  }

  TextStyle _cuteTextStyle({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w700,
    Color color = Colors.white,
  }) {
    return GoogleFonts.baloo2(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _storyPages[_currentPage];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              widget.story['color'].withValues(alpha: 0.3),
              widget.story['color'].withValues(alpha: 0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          // UCD015 maps storyIndex to activity id
                          final actId =
                              widget.storyIndex < _storyActivityIds.length
                                  ? _storyActivityIds[widget.storyIndex]
                                  : 'story_unknown';
                          ActivityExitHandler.handleExitActivity(
                            context: context,
                            activityId: actId,
                            activityEmoji: widget.story['emoji'] ?? '📖',
                            buildProgressData: () => {
                              'currentPage': _currentPage,
                            },
                          );
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: widget.story['color'],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back,
                              color: Colors.white, size: 30),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          widget.story['title'],
                          style: _cuteTextStyle(
                            fontSize: 36,
                            color: widget.story['color'],
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Progress
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: widget.story['color'],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentPage + 1} / ${_storyPages.length}',
                          style: _cuteTextStyle(fontSize: 22),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // UCD015: Help button
                      HelpButton(
                        activityId: widget.storyIndex < _storyActivityIds.length
                            ? _storyActivityIds[widget.storyIndex]
                            : '',
                        activityEmoji: widget.story['emoji'] ?? '📖',
                        activityName: widget.story['title'] ?? 'Story',
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Story Emoji
                        Text(page['emoji'],
                            style: const TextStyle(fontSize: 80)),
                        const SizedBox(height: 25),

                        // Story Text
                        Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: widget.story['color']
                                    .withValues(alpha: 0.3),
                                blurRadius: 20,
                              ),
                            ],
                            border: Border.all(
                                color: widget.story['color'], width: 4),
                          ),
                          child: Text(
                            page['text'],
                            style: _cuteTextStyle(
                              fontSize: 28,
                              color: const Color(0xFF333333),
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Question
                        Text(
                          page['question'],
                          style: _cuteTextStyle(
                            fontSize: 32,
                            color: widget.story['color'],
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        const SizedBox(height: 25),

                        // Choices
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children:
                              (page['choices'] as List).map<Widget>((choice) {
                            final isSelected =
                                _selectedChoice == choice['text'];
                            return GestureDetector(
                              onTap: _selectedChoice == null
                                  ? () => _nextPage(choice['text'])
                                  : null,
                              child: AnimatedScale(
                                scale: isSelected ? 1.15 : 1.0,
                                duration: const Duration(milliseconds: 300),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 200,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 15),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        choice['color'],
                                        choice['color'].withValues(alpha: 0.7),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(25),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.yellow
                                          : Colors.white,
                                      width: isSelected ? 6 : 4,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: choice['color'].withValues(
                                            alpha: isSelected ? 0.7 : 0.4),
                                        blurRadius: isSelected ? 20 : 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Text(choice['emoji'],
                                          style: const TextStyle(fontSize: 50)),
                                      const SizedBox(height: 10),
                                      Text(
                                        choice['text'],
                                        style: _cuteTextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
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
