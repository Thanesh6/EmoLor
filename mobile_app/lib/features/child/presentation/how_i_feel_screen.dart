import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/emotion_service.dart';
import '../../../core/services/emotion_colour_mapping.dart';
import '../domain/models/emotion.dart';
import '../services/child_session_service.dart';

enum HowIFeelMode { start, end }

class HowIFeelScreen extends StatefulWidget {
  final HowIFeelMode mode;
  final String? childName;
  final Future<void> Function(HowIFeelEmotionChoice choice) onContinue;
  final VoidCallback? onBack;

  const HowIFeelScreen({
    super.key,
    required this.mode,
    required this.onContinue,
    this.childName,
    this.onBack,
  });

  @override
  State<HowIFeelScreen> createState() => _HowIFeelScreenState();
}

class HowIFeelEmotionChoice {
  final String id;
  final String name;
  final String emoji;
  final Color color;
  final String valence;
  const HowIFeelEmotionChoice(this.id, this.name, this.emoji, this.color, this.valence);
}

class _HowIFeelScreenState extends State<HowIFeelScreen>
    with TickerProviderStateMixin {

  HowIFeelEmotionChoice? _selected;
  List<Emotion> _emotions = EmotionService.defaultEmotions;
  late final AnimationController _pulse;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
    _loadEmotions();
  }

  Future<void> _loadEmotions() async {
    await EmotionColourMapping.ensureLoaded();
    final loaded = await EmotionService.loadEmotionsStatic();
    if (mounted) setState(() => _emotions = loaded);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  TextStyle _cute({
    double size = 22,
    FontWeight weight = FontWeight.w700,
    Color color = Colors.white,
    List<Shadow>? shadows,
  }) =>
      GoogleFonts.baloo2(fontSize: size, fontWeight: weight, color: color, shadows: shadows);

  Future<void> _saveMoodLocally(HowIFeelEmotionChoice choice) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keySuffix = widget.mode == HowIFeelMode.start ? 'start' : 'end';
      await prefs.setString('how_i_feel_${keySuffix}_id', choice.id);
      await prefs.setString('how_i_feel_${keySuffix}_name', choice.name);
      await prefs.setString('how_i_feel_${keySuffix}_at', DateTime.now().toIso8601String());
    } catch (_) {}
  }

  Future<void> _saveMoodToDatabase(HowIFeelEmotionChoice choice) async {
    final hex = EmotionColourMapping.hexFor(choice.name);
    try {
      if (widget.mode == HowIFeelMode.start) {
        await ChildSessionService.recordPreEmotion(
          emotionName: choice.name,
          emotionValence: choice.valence,
          emotionColourHex: hex,
        );
      } else {
        await ChildSessionService.recordPostEmotion(
          emotionName: choice.name,
          emotionValence: choice.valence,
          emotionColourHex: hex,
        );
      }
    } catch (e) {
      debugPrint('HowIFeelScreen._saveMoodToDatabase: $e');
    }
  }

  Future<void> _handleContinue() async {
    if (_selected == null || _busy) return;
    setState(() => _busy = true);
    await _saveMoodLocally(_selected!);
    await _saveMoodToDatabase(_selected!);
    try {
      await widget.onContinue(_selected!);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _title => widget.mode == HowIFeelMode.start
      ? 'How do you feel today?'
      : 'How are you feeling now?';

  String get _subtitle => widget.mode == HowIFeelMode.start
      ? 'Tap the emoji that matches you right now'
      : 'Thanks for playing! Tap how you feel now';

  String get _ctaLabel => widget.mode == HowIFeelMode.start ? 'Continue' : 'Done';
  IconData get _ctaIcon =>
      widget.mode == HowIFeelMode.start ? Icons.arrow_forward_rounded : Icons.check_rounded;

  @override
  Widget build(BuildContext context) {
    final greeting = (widget.childName != null && widget.childName!.isNotEmpty)
        ? 'Hi ${widget.childName} !'
        : 'Hello friend !';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE8F0), Color(0xFFE0C3FC), Color(0xFF8EC5FC)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                        child: Column(
                          children: [
                            Text(greeting,
                                style: _cute(size: 26, weight: FontWeight.w700,
                                    color: const Color(0xFF6B21A8))),
                            const SizedBox(height: 4),
                            Text(_title,
                                style: _cute(
                                  size: 38,
                                  weight: FontWeight.w900,
                                  color: const Color(0xFF1B2541),
                                  shadows: const [
                                    Shadow(offset: Offset(2, 2), blurRadius: 4, color: Colors.black26),
                                  ],
                                ),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 4),
                            Text(_subtitle,
                                style: _cute(size: 17, weight: FontWeight.w500,
                                    color: Colors.black54),
                                textAlign: TextAlign.center),
                          ],
                        ),
                      ),

                      // Emotion cards grid — uses child's OWN mapped colours
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
                          child: GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 0.88,
                            ),
                            itemCount: _emotions.length,
                            itemBuilder: (context, i) {
                              final e = _emotions[i];
                              final cardColor = e.color; // child's mapped colour
                              final isSelected = _selected?.id == e.id;
                              return AnimatedBuilder(
                                animation: _pulse,
                                builder: (context, child) => Transform.scale(
                                  scale: isSelected
                                      ? 1.0 + (_pulse.value * 0.04)
                                      : 1.0,
                                  child: child,
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selected = HowIFeelEmotionChoice(
                                        e.id, e.name, e.emoji, cardColor, e.valence,
                                      );
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          cardColor,
                                          cardColor.withValues(alpha: 0.75),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.yellow
                                            : Colors.white,
                                        width: isSelected ? 4.5 : 3.0,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: cardColor.withValues(
                                              alpha: isSelected ? 0.65 : 0.3),
                                          blurRadius: isSelected ? 20 : 10,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(e.emoji,
                                            style: const TextStyle(fontSize: 68)),
                                        const SizedBox(height: 4),
                                        Text(
                                          e.name,
                                          style: _cute(
                                            size: 24,
                                            weight: FontWeight.w800,
                                            shadows: const [
                                              Shadow(offset: Offset(1, 1),
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

                      // Continue / Done button
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 22),
                        child: SizedBox(
                          width: 320,
                          height: 64,
                          child: ElevatedButton.icon(
                            onPressed: _selected == null || _busy
                                ? null
                                : _handleContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _selected?.color ?? Colors.grey.shade300,
                              disabledBackgroundColor: Colors.grey.shade200,
                              foregroundColor: Colors.white,
                              elevation: _selected != null ? 6 : 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            icon: _busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 3, color: Colors.white))
                                : Icon(_ctaIcon, size: 28),
                            label: Text(
                              _ctaLabel,
                              style: _cute(
                                size: 24,
                                weight: FontWeight.w800,
                                color: _selected != null
                                    ? Colors.white
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Back button (start mode only)
                  if (widget.mode == HowIFeelMode.start && widget.onBack != null)
                    Positioned(
                      top: 10,
                      left: 14,
                      child: GestureDetector(
                        onTap: widget.onBack,
                        child: Container(
                          padding: const EdgeInsets.all(12),
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
                              color: Color(0xFF6B21A8), size: 30),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
