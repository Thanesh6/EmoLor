import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/logic/adaptive_engine.dart';
import '../core/widgets/star_reward_widget.dart';

class ExpressCardsScreen extends StatefulWidget {
  const ExpressCardsScreen({super.key});

  @override
  State<ExpressCardsScreen> createState() => _ExpressCardsScreenState();
}

class _ExpressCardsScreenState extends State<ExpressCardsScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  String _selectedCategory = 'feelings';
  Map<String, dynamic>? _selectedCard;
  late AnimationController _celebrateController;

  // Adaptive Engine for behavioral tracking
  final AdaptiveEngine _adaptiveEngine = AdaptiveEngine(
    hesitationThresholdMs: 10000,
    frustrationThreshold: 3,
    overloadTapsPerSecond: 5.0,
  );

  final Map<String, List<Map<String, dynamic>>> _categories = {
    'feelings': [
      {
        'name': 'Happy',
        'emoji': '😊',
        'color': const Color(0xFFFFB088),
        'gradient': [const Color(0xFFFFB088), const Color(0xFFFF9A6C)]
      },
      {
        'name': 'Sad',
        'emoji': '😢',
        'color': const Color(0xFF74B9FF),
        'gradient': [const Color(0xFF74B9FF), const Color(0xFF0984E3)]
      },
      {
        'name': 'Angry',
        'emoji': '😠',
        'color': const Color(0xFFFF6B6B),
        'gradient': [const Color(0xFFFF6B6B), const Color(0xFFEE5A5A)]
      },
      {
        'name': 'Scared',
        'emoji': '😨',
        'color': const Color(0xFFBB6BD9),
        'gradient': [const Color(0xFFBB6BD9), const Color(0xFF9B59B6)]
      },
      {
        'name': 'Excited',
        'emoji': '🤩',
        'color': const Color(0xFFFF9F43),
        'gradient': [const Color(0xFFFF9F43), const Color(0xFFE17055)]
      },
      {
        'name': 'Calm',
        'emoji': '😌',
        'color': const Color(0xFF4ECDC4),
        'gradient': [const Color(0xFF4ECDC4), const Color(0xFF26D0CE)]
      },
      {
        'name': 'Tired',
        'emoji': '😴',
        'color': const Color(0xFF636E72),
        'gradient': [const Color(0xFF636E72), const Color(0xFF2D3436)]
      },
      {
        'name': 'Loved',
        'emoji': '🥰',
        'color': const Color(0xFFFF7EB3),
        'gradient': [const Color(0xFFFF7EB3), const Color(0xFFFF758F)]
      },
      {
        'name': 'Confused',
        'emoji': '😕',
        'color': const Color(0xFFA29BFE),
        'gradient': [const Color(0xFFA29BFE), const Color(0xFF6C5CE7)]
      },
      {
        'name': 'Proud',
        'emoji': '😎',
        'color': const Color(0xFF7ED957),
        'gradient': [const Color(0xFF7ED957), const Color(0xFF00B894)]
      },
      {
        'name': 'Shy',
        'emoji': '🙈',
        'color': const Color(0xFFFDAA94),
        'gradient': [const Color(0xFFFDAA94), const Color(0xFFE17055)]
      },
      {
        'name': 'Silly',
        'emoji': '🤪',
        'color': const Color(0xFF00CEC9),
        'gradient': [const Color(0xFF00CEC9), const Color(0xFF55EFC4)]
      },
    ],
    'needs': [
      {
        'name': 'Help Me',
        'emoji': '🆘',
        'color': const Color(0xFFFFADAD),
        'gradient': [const Color(0xFFFFADAD), const Color(0xFFFF8A8A)]
      },
      {
        'name': 'Break',
        'emoji': '⏸️',
        'color': const Color(0xFF74B9FF),
        'gradient': [const Color(0xFF74B9FF), const Color(0xFF0984E3)]
      },
      {
        'name': 'Hug',
        'emoji': '🤗',
        'color': const Color(0xFFFF7EB3),
        'gradient': [const Color(0xFFFF7EB3), const Color(0xFFFF6B81)]
      },
      {
        'name': 'Water',
        'emoji': '💧',
        'color': const Color(0xFFB8D4E3),
        'gradient': [const Color(0xFFB8D4E3), const Color(0xFF8FB8D0)]
      },
      {
        'name': 'Food',
        'emoji': '🍎',
        'color': const Color(0xFFFF6B6B),
        'gradient': [const Color(0xFFFF6B6B), const Color(0xFFE17055)]
      },
      {
        'name': 'Toilet',
        'emoji': '🚽',
        'color': const Color(0xFFFDCB6E),
        'gradient': [const Color(0xFFFDCB6E), const Color(0xFFE17055)]
      },
      {
        'name': 'Quiet',
        'emoji': '🤫',
        'color': const Color(0xFFBB6BD9),
        'gradient': [const Color(0xFFBB6BD9), const Color(0xFF6C5CE7)]
      },
      {
        'name': 'Space',
        'emoji': '🧘',
        'color': const Color(0xFF55EFC4),
        'gradient': [const Color(0xFF55EFC4), const Color(0xFF00B894)]
      },
      {
        'name': 'Sleep',
        'emoji': '🛏️',
        'color': const Color(0xFF636E72),
        'gradient': [const Color(0xFF636E72), const Color(0xFF2D3436)]
      },
      {
        'name': 'Medicine',
        'emoji': '💊',
        'color': const Color(0xFFFF7675),
        'gradient': [const Color(0xFFFF7675), const Color(0xFFD63031)]
      },
      {
        'name': 'Sensory',
        'emoji': '🎧',
        'color': const Color(0xFFA29BFE),
        'gradient': [const Color(0xFFA29BFE), const Color(0xFF6C5CE7)]
      },
      {
        'name': 'Comfort',
        'emoji': '🧸',
        'color': const Color(0xFFDEB887),
        'gradient': [const Color(0xFFDEB887), const Color(0xFFD4A574)]
      },
    ],
    'actions': [
      {
        'name': 'Play',
        'emoji': '🎮',
        'color': const Color(0xFF7ED957),
        'gradient': [const Color(0xFF7ED957), const Color(0xFF00B894)]
      },
      {
        'name': 'Draw',
        'emoji': '🖌️',
        'color': const Color(0xFF63CDDA),
        'gradient': [const Color(0xFF63CDDA), const Color(0xFF3DC1D3)]
      },
      {
        'name': 'Music',
        'emoji': '🎵',
        'color': const Color(0xFFBB6BD9),
        'gradient': [const Color(0xFFBB6BD9), const Color(0xFF9B59B6)]
      },
      {
        'name': 'Outside',
        'emoji': '🌳',
        'color': const Color(0xFF55EFC4),
        'gradient': [const Color(0xFF55EFC4), const Color(0xFF00B894)]
      },
      {
        'name': 'Read',
        'emoji': '📚',
        'color': const Color(0xFF74B9FF),
        'gradient': [const Color(0xFF74B9FF), const Color(0xFF0984E3)]
      },
      {
        'name': 'Watch',
        'emoji': '📺',
        'color': const Color(0xFF636E72),
        'gradient': [const Color(0xFF636E72), const Color(0xFF2D3436)]
      },
      {
        'name': 'Dance',
        'emoji': '💃',
        'color': const Color(0xFFFF7EB3),
        'gradient': [const Color(0xFFFF7EB3), const Color(0xFFFF6B81)]
      },
      {
        'name': 'Build',
        'emoji': '🧱',
        'color': const Color(0xFFE17055),
        'gradient': [const Color(0xFFE17055), const Color(0xFFD63031)]
      },
      {
        'name': 'Puzzle',
        'emoji': '🧩',
        'color': const Color(0xFFFFE66D),
        'gradient': [const Color(0xFFFFE66D), const Color(0xFFFDAA94)]
      },
      {
        'name': 'Cook',
        'emoji': '👨‍🍳',
        'color': const Color(0xFFFDAA94),
        'gradient': [const Color(0xFFFDAA94), const Color(0xFFE17055)]
      },
      {
        'name': 'Exercise',
        'emoji': '🤸',
        'color': const Color(0xFF00CEC9),
        'gradient': [const Color(0xFF00CEC9), const Color(0xFF55EFC4)]
      },
      {
        'name': 'Crafts',
        'emoji': '✂️',
        'color': const Color(0xFFA29BFE),
        'gradient': [const Color(0xFFA29BFE), const Color(0xFF6C5CE7)]
      },
    ],
    'responses': [
      {
        'name': 'Yes',
        'emoji': '✅',
        'color': const Color(0xFF7ED957),
        'gradient': [const Color(0xFF7ED957), const Color(0xFF00B894)]
      },
      {
        'name': 'No',
        'emoji': '❌',
        'color': const Color(0xFF778BEB),
        'gradient': [const Color(0xFF778BEB), const Color(0xFF546DE5)]
      },
      {
        'name': 'Maybe',
        'emoji': '🤔',
        'color': const Color(0xFFFFE66D),
        'gradient': [const Color(0xFFFFE66D), const Color(0xFFFFD93D)]
      },
      {
        'name': 'More',
        'emoji': '➕',
        'color': const Color(0xFF74B9FF),
        'gradient': [const Color(0xFF74B9FF), const Color(0xFF0984E3)]
      },
      {
        'name': 'All Done',
        'emoji': '✋',
        'color': const Color(0xFFFF9F43),
        'gradient': [const Color(0xFFFF9F43), const Color(0xFFE17055)]
      },
      {
        'name': 'Wait',
        'emoji': '⏳',
        'color': const Color(0xFFA29BFE),
        'gradient': [const Color(0xFFA29BFE), const Color(0xFF6C5CE7)]
      },
      {
        'name': 'Again',
        'emoji': '🔄',
        'color': const Color(0xFF00CEC9),
        'gradient': [const Color(0xFF00CEC9), const Color(0xFF55EFC4)]
      },
      {
        'name': 'Stop',
        'emoji': '🛑',
        'color': const Color(0xFF786FA6),
        'gradient': [const Color(0xFF786FA6), const Color(0xFF574B90)]
      },
      {
        'name': 'Thank You',
        'emoji': '🙏',
        'color': const Color(0xFFFF7EB3),
        'gradient': [const Color(0xFFFF7EB3), const Color(0xFFFF6B81)]
      },
      {
        'name': 'Sorry',
        'emoji': '😔',
        'color': const Color(0xFF636E72),
        'gradient': [const Color(0xFF636E72), const Color(0xFF2D3436)]
      },
      {
        'name': 'Please',
        'emoji': '🙂',
        'color': const Color(0xFF55EFC4),
        'gradient': [const Color(0xFF55EFC4), const Color(0xFF00B894)]
      },
      {
        'name': 'I Love You',
        'emoji': '❤️',
        'color': const Color(0xFFF8CD65),
        'gradient': [const Color(0xFFF8CD65), const Color(0xFFF5B731)]
      },
    ],
  };

  final Map<String, Map<String, dynamic>> _categoryInfo = {
    'feelings': {
      'name': 'How I Feel',
      'emoji': '💭',
      'color': const Color(0xFFFF7EB3)
    },
    'needs': {
      'name': 'What I Need',
      'emoji': '🤲',
      'color': const Color(0xFF74B9FF)
    },
    'actions': {
      'name': 'What I Want',
      'emoji': '🎯',
      'color': const Color(0xFF7ED957)
    },
    'responses': {
      'name': 'My Answer',
      'emoji': '💬',
      'color': const Color(0xFFFFE66D)
    },
  };

  // For simplified UI mode
  bool _isSimplified = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);

    _celebrateController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Start latency tracking
    _adaptiveEngine.markPromptShown();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _celebrateController.dispose();
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

  void _onCardTap(Map<String, dynamic> card) {
    // Track tap frequency
    _adaptiveEngine.recordTap();

    // Record latency on first card selection
    _adaptiveEngine.recordTapLatency();

    // Check for overload behavior
    if (_adaptiveEngine.isOverloaded && !_isSimplified) {
      _simplifyUI();
    }

    setState(() => _selectedCard = card);
    _celebrateController.forward(from: 0);

    // Show Star Reward on card selection!
    StarRewardWidget.show(context);

    // Show feedback dialog
    Future.delayed(const Duration(milliseconds: 300), () {
      _showCardFeedback(card);
    });
  }

  void _simplifyUI() {
    setState(() {
      _isSimplified = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Let\'s keep it simple... 🧘',
            style: GoogleFonts.fredoka(fontSize: 16)),
        backgroundColor: Colors.purple,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  void _showCardFeedback(Map<String, dynamic> card) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: AnimatedBuilder(
          animation: _celebrateController,
          builder: (context, child) {
            return Transform.scale(
              scale: 0.8 + (_celebrateController.value * 0.2),
              child: child,
            );
          },
          child: Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: card['gradient'],
              ),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white, width: 6),
              boxShadow: [
                BoxShadow(
                  color: card['color'].withValues(alpha: 0.5),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(card['emoji'], style: const TextStyle(fontSize: 144)),
                const SizedBox(height: 20),
                Text(
                  card['name'],
                  style: _cuteTextStyle(
                    fontSize: 58,
                    fontWeight: FontWeight.w900,
                    shadows: const [
                      Shadow(
                          offset: Offset(3, 3),
                          blurRadius: 6,
                          color: Colors.black38),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                Text(
                  '✨ Great job expressing yourself! ✨',
                  style: _cuteTextStyle(fontSize: 22),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() => _selectedCard = null);
                    // Restart latency tracking for next selection
                    _adaptiveEngine.markPromptShown();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 35, vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25)),
                  ),
                  child: Text(
                    '👍 OK',
                    style: _cuteTextStyle(fontSize: 28, color: card['color']),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get cards - show fewer when simplified
    List<Map<String, dynamic>> currentCards = _categories[_selectedCategory]!;
    if (_isSimplified) {
      currentCards = currentCards.take(6).toList(); // Show only first 6 cards
    }
    final categoryInfo = _categoryInfo[_selectedCategory]!;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              categoryInfo['color'].withValues(alpha: 0.3),
              Colors.white,
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
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Express Cards',
                          style: _cuteTextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF1B2541),
                            shadows: const [
                              Shadow(
                                  offset: Offset(3, 3),
                                  blurRadius: 6,
                                  color: Colors.black26),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),
                        const Text('💬', style: TextStyle(fontSize: 50)),
                      ],
                    ),
                  ),

                  // Category Tabs
                  Container(
                    height: 80,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: _categoryInfo.entries.map((entry) {
                        final isSelected = _selectedCategory == entry.key;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _adaptiveEngine.recordTap();
                              setState(() => _selectedCategory = entry.key);
                              _adaptiveEngine.markPromptShown();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? LinearGradient(colors: [
                                        entry.value['color'],
                                        entry.value['color']
                                            .withValues(alpha: 0.7)
                                      ])
                                    : null,
                                color: isSelected ? null : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : entry.value['color'],
                                  width: 3,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                            color: entry.value['color']
                                                .withValues(alpha: 0.4),
                                            blurRadius: 10)
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(entry.value['emoji'],
                                      style: const TextStyle(fontSize: 28)),
                                  Text(
                                    entry.value['name'],
                                    style: _cuteTextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? Colors.white
                                          : entry.value['color'],
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

                  const SizedBox(height: 15),

                  // Current Category Title
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        categoryInfo['color'],
                        categoryInfo['color'].withValues(alpha: 0.7)
                      ]),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(
                      '${categoryInfo['emoji']} ${categoryInfo['name']}',
                      style: _cuteTextStyle(
                          fontSize: 28, fontWeight: FontWeight.w900),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Cards Grid
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _isSimplified
                              ? 3
                              : 4, // Fewer columns when simplified
                          crossAxisSpacing: 22,
                          mainAxisSpacing: 22,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: currentCards.length,
                        itemBuilder: (context, index) {
                          final card = currentCards[index];
                          final isSelected = _selectedCard == card;

                          return AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: isSelected
                                    ? 1.0 + (_pulseController.value * 0.05)
                                    : 1.0,
                                child: child,
                              );
                            },
                            child: GestureDetector(
                              onTap: () => _onCardTap(card),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: card['gradient'],
                                  ),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.yellow
                                        : Colors.white,
                                    width: isSelected ? 4.5 : 3.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: card['color'].withValues(
                                          alpha: isSelected ? 0.6 : 0.4),
                                      blurRadius: isSelected ? 20 : 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(card['emoji'],
                                        style: const TextStyle(fontSize: 78)),
                                    const SizedBox(height: 8),
                                    Text(
                                      card['name'],
                                      style: _cuteTextStyle(
                                        fontSize: 29,
                                        fontWeight: FontWeight.w800,
                                        shadows: const [
                                          Shadow(
                                              offset: Offset(1, 1),
                                              blurRadius: 3,
                                              color: Colors.black26),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
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
                    padding: const EdgeInsets.all(12),
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
