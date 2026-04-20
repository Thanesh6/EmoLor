import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mood check-in screen used in two phases:
///
///   * `HowIFeelMode.start` – shown right after profile selection to let the
///     child tell us how they feel before starting the session.
///   * `HowIFeelMode.end`   – shown right before logout / switch / goal-time
///     end to let the child tell us how they feel after the session.
///
/// The mood is persisted (SharedPreferences, lightweight) so we can pair the
/// start/end pair together later for analytics.
enum HowIFeelMode { start, end }

class HowIFeelScreen extends StatefulWidget {
  final HowIFeelMode mode;
  final String? childName;

  /// Called once the child taps an emoji + Continue. The caller decides what
  /// comes next (Phase 2 / logout / switch / pop).
  final Future<void> Function(HowIFeelMoodChoice choice) onContinue;

  /// Optional — if provided, a back button is shown on the start-mode screen
  /// that calls this. Typically returns to the profile selection screen.
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

class HowIFeelMoodChoice {
  final String id;
  final String name;
  final String emoji;
  final Color color;
  const HowIFeelMoodChoice(this.id, this.name, this.emoji, this.color);
}

class _HowIFeelScreenState extends State<HowIFeelScreen>
    with TickerProviderStateMixin {
  // Same 12 feelings as Express Cards → "How I Feel" category,
  // keeps the visual language consistent across the app.
  static const List<HowIFeelMoodChoice> _moods = [
    HowIFeelMoodChoice('happy', 'Happy', '😊', Color(0xFFFFB088)),
    HowIFeelMoodChoice('sad', 'Sad', '😢', Color(0xFF74B9FF)),
    HowIFeelMoodChoice('angry', 'Angry', '😠', Color(0xFFFF6B6B)),
    HowIFeelMoodChoice('scared', 'Scared', '😨', Color(0xFFBB6BD9)),
    HowIFeelMoodChoice('excited', 'Excited', '🤩', Color(0xFFFF9F43)),
    HowIFeelMoodChoice('calm', 'Calm', '😌', Color(0xFF4ECDC4)),
    HowIFeelMoodChoice('tired', 'Tired', '😴', Color(0xFF636E72)),
    HowIFeelMoodChoice('loved', 'Loved', '🥰', Color(0xFFFF7EB3)),
    HowIFeelMoodChoice('confused', 'Confused', '😕', Color(0xFFA29BFE)),
    HowIFeelMoodChoice('proud', 'Proud', '😎', Color(0xFF7ED957)),
    HowIFeelMoodChoice('shy', 'Shy', '🙈', Color(0xFFFDAA94)),
    HowIFeelMoodChoice('silly', 'Silly', '🤪', Color(0xFF00CEC9)),
  ];

  HowIFeelMoodChoice? _selected;
  late final AnimationController _pulse;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
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
      GoogleFonts.baloo2(
        fontSize: size,
        fontWeight: weight,
        color: color,
        shadows: shadows,
      );

  Future<void> _saveMood(HowIFeelMoodChoice choice) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keySuffix = widget.mode == HowIFeelMode.start ? 'start' : 'end';
      final now = DateTime.now().toIso8601String();
      await prefs.setString('how_i_feel_${keySuffix}_id', choice.id);
      await prefs.setString('how_i_feel_${keySuffix}_name', choice.name);
      await prefs.setString('how_i_feel_${keySuffix}_at', now);
    } catch (_) {
      // best-effort — never block the flow on a storage failure
    }
  }

  Future<void> _handleContinue() async {
    if (_selected == null || _busy) return;
    setState(() => _busy = true);
    await _saveMood(_selected!);
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

  String get _ctaLabel => widget.mode == HowIFeelMode.start
      ? 'Continue'
      : 'Done';

  IconData get _ctaIcon => widget.mode == HowIFeelMode.start
      ? Icons.arrow_forward_rounded
      : Icons.check_rounded;

  @override
  Widget build(BuildContext context) {
    final greeting = widget.childName != null && widget.childName!.isNotEmpty
        ? 'Hi ${widget.childName} !'
        : 'Hello friend !';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFE8F0),
              Color(0xFFE0C3FC),
              Color(0xFF8EC5FC),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
              Column(
                children: [
                  // ───── Header ─────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                    child: Column(
                      children: [
                        Text(
                          greeting,
                          style: _cute(
                            size: 26,
                            weight: FontWeight.w700,
                            color: const Color(0xFF6B21A8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _title,
                          style: _cute(
                            size: 44,
                            weight: FontWeight.w900,
                            color: const Color(0xFF1B2541),
                            shadows: const [
                              Shadow(
                                offset: Offset(2, 2),
                                blurRadius: 4,
                                color: Colors.black26,
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _subtitle,
                          style: _cute(
                            size: 18,
                            weight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // ───── Emoji grid ─────
                  Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(28, 10, 28, 6),
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 18,
                          mainAxisSpacing: 18,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: _moods.length,
                        itemBuilder: (context, i) {
                          final m = _moods[i];
                          final isSelected = _selected?.id == m.id;
                          return AnimatedBuilder(
                            animation: _pulse,
                            builder: (context, child) => Transform.scale(
                              scale: isSelected
                                  ? 1.0 + (_pulse.value * 0.04)
                                  : 1.0,
                              child: child,
                            ),
                            child: GestureDetector(
                              onTap: () => setState(() => _selected = m),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 220),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      m.color,
                                      m.color.withValues(alpha: 0.75),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.yellow
                                        : Colors.white,
                                    width: isSelected ? 4.5 : 3.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: m.color.withValues(
                                        alpha: isSelected ? 0.65 : 0.35,
                                      ),
                                      blurRadius:
                                          isSelected ? 22 : 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Text(m.emoji,
                                        style: const TextStyle(
                                            fontSize: 79)),
                                    const SizedBox(height: 6),
                                    Text(
                                      m.name,
                                      style: _cute(
                                        size: 29,
                                        weight: FontWeight.w800,
                                        shadows: const [
                                          Shadow(
                                            offset: Offset(1, 1),
                                            blurRadius: 3,
                                            color: Colors.black26,
                                          ),
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

                  // ───── Continue button ─────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 22),
                    child: SizedBox(
                      width: 320,
                      height: 64,
                      child: ElevatedButton.icon(
                        onPressed:
                            _selected == null || _busy ? null : _handleContinue,
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
                                  strokeWidth: 3,
                                  color: Colors.white,
                                ),
                              )
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
              // ───── Back button overlay (start mode only) ─────
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
              );
            },
          ),
        ),
      ),
    );
  }
}
