import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import '../../../../core/services/emotion_colour_mapping.dart';

class EmotionMatchGame extends StatefulWidget {
  const EmotionMatchGame({super.key});

  @override
  State<EmotionMatchGame> createState() => _EmotionMatchGameState();
}

class _EmotionMatchGameState extends State<EmotionMatchGame> {
  late ConfettiController _confettiController;
  int _score = 0;
  int _mistakes = 0;
  bool _isFrustrated = false; // Adaptive Sensory Engine state

  late final List<Map<String, dynamic>> _levels = [
    {'word': 'Happy', 'color': EmotionColourMapping.colorFor('Happy')},
    {'word': 'Sad', 'color': EmotionColourMapping.colorFor('Sad')},
    {'word': 'Angry', 'color': EmotionColourMapping.colorFor('Angry')},
    {'word': 'Calm', 'color': EmotionColourMapping.colorFor('Calm')},
  ];

  late Map<String, dynamic> _currentLevel;
  late List<Color> _options;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    _startNewLevel();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _startNewLevel() {
    setState(() {
      _currentLevel = _levels[Random().nextInt(_levels.length)];
      _generateOptions();
    });
  }

  void _generateOptions() {
    // Adaptive Logic: If frustrated (mistakes > 3), show fewer options (2 instead of 4)
    int optionCount = _isFrustrated ? 2 : 4;

    Set<Color> optionsSet = {_currentLevel['color']};
    while (optionsSet.length < optionCount) {
      optionsSet
          .add(Colors.primaries[Random().nextInt(Colors.primaries.length)]);
    }
    _options = optionsSet.toList()..shuffle();
  }

  void _handleSelection(Color selectedColor) {
    if (selectedColor == _currentLevel['color']) {
      // Correct
      _confettiController.play();
      setState(() {
        _score++;
        _mistakes = 0; // Reset mistakes streak
        _isFrustrated = false; // Reset frustration state
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _startNewLevel();
      });
    } else {
      // Incorrect
      setState(() {
        _mistakes++;
        if (_mistakes >= 3) {
          _isFrustrated = true; // Trigger Adaptive Sensory Engine
          _generateOptions(); // Regenerate with fewer options immediately
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFrustrated ? "Let's make it easier!" : "Try again!"),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Score: $_score'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Find the color for:',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                _currentLevel['word'],
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
              ),
              const SizedBox(height: 48),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: _options.map((color) {
                  return GestureDetector(
                    onTap: () => _handleSelection(color),
                    child: Container(
                      width: _isFrustrated
                          ? 120
                          : 80, // Larger targets if frustrated
                      height: _isFrustrated ? 120 : 80,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_isFrustrated)
                Padding(
                  padding: const EdgeInsets.only(top: 32.0),
                  child: Text(
                    "Adaptive Mode Active: Simplified View",
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple
            ],
          ),
        ],
      ),
    );
  }
}
