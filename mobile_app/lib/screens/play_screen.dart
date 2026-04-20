import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'emotion_slash_screen.dart';
import 'emoji_spelling_screen.dart';
import 'animal_sound_screen.dart';
import 'emotion_bubbles_screen.dart';
import 'emoji_puzzle_screen.dart';
import 'emotion_catcher_screen.dart';
import 'emo_match_screen.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> with TickerProviderStateMixin {
  late AnimationController _bounceController;

  final List<Map<String, dynamic>> _games = [
    {
      'name': 'EMOZZLE',
      'emoji': '🧩',
      'color': const Color(0xFF2D8B4E),
      'desc': 'Build the Emoji',
      'screen': const EmojiPuzzleScreen()
    },
    {
      'name': 'EMOPOP',
      'emoji': '🫧',
      'color': const Color(0xFFFF7EB3),
      'desc': 'Pop the Emoji',
      'screen': const EmotionBubblesScreen()
    },
    {
      'name': 'EMOSPELL',
      'emoji': '🔤',
      'color': const Color(0xFFFF9F43),
      'desc': 'Spell the Emoji',
      'screen': const EmojiSpellingScreen()
    },
    {
      'name': 'EMOMATCH',
      'emoji': '🌟',
      'color': const Color(0xFFE67E22),
      'desc': 'Match the Item',
      'screen': const EmoMatchScreen()
    },
    {
      'name': 'EMOSLASH',
      'emoji': '⚔️',
      'color': const Color(0xFF4ECDC4),
      'desc': 'Slash the Emoji',
      'screen': const EmotionSlashScreen()
    },
    {
      'name': 'EMOCATCH',
      'emoji': '🧺',
      'color': const Color(0xFF5D9CEC),
      'desc': 'Catch the Emoji',
      'screen': const EmotionCatcherScreen()
    },
    {
      'name': 'ANIMATCH',
      'emoji': '🐾',
      'color': const Color(0xFFBB6BD9),
      'desc': 'Match the Sound',
      'screen': const AnimalSoundScreen()
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
              Color(0xFFFF9A9E),
              Color(0xFFFECFEF),
              Color(0xFFFECFEF),
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
                        Text(
                          'Let\'s Play!',
                          style: _cuteTextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF1B2541),
                            shadows: const [
                              Shadow(
                                  offset: Offset(2, 2),
                                  blurRadius: 6,
                                  color: Color(0x33000000)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),
                        const Text('🎲', style: TextStyle(fontSize: 50)),
                      ],
                    ),
                  ),

                  // Subtitle
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 25, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(
                      '🌟 Pick a game to play! 🌟',
                      style: _cuteTextStyle(
                          fontSize: 24, color: const Color(0xFF6B21A8)),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Game Grid
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 25,
                          mainAxisSpacing: 25,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: _games.length,
                        itemBuilder: (context, index) {
                          final game = _games[index];
                          return AnimatedBuilder(
                            animation: _bounceController,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(
                                    0,
                                    -5 *
                                        _bounceController.value *
                                        (index % 2 == 0 ? 1 : -1)),
                                child: child,
                              );
                            },
                            child: GestureDetector(
                              onTap: () {
                                if (game['screen'] != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => game['screen']),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          '${game['name']} is Coming Soon! 🚧'),
                                      backgroundColor: game['color'],
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      game['color'],
                                      game['color'].withValues(alpha: 0.7),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          game['color'].withValues(alpha: 0.4),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                  border:
                                      Border.all(color: Colors.white, width: 5),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(game['emoji'],
                                        style: const TextStyle(
                                          fontSize: 90,
                                          fontFamilyFallback: [
                                            'Segoe UI Emoji',
                                            'Apple Color Emoji',
                                            'Noto Color Emoji'
                                          ],
                                        )),
                                    const SizedBox(height: 14),
                                    Text(
                                      game['name'],
                                      style: _cuteTextStyle(
                                        fontSize: 42,
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
                                    const SizedBox(height: 5),
                                    Text(
                                      game['desc'],
                                      style: _cuteTextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w600,
                                        shadows: const [
                                          Shadow(
                                              offset: Offset(1, 1),
                                              blurRadius: 3,
                                              color: Colors.black26),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
              // Back Button
              Positioned(
                top: 20,
                left: 20,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(13),
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
                      size: 34,
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
