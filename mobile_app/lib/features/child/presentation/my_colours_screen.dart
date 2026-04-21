import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/emotion_service.dart';
import '../domain/models/emotion.dart';

/// UCD017 - My Colours (redesigned)
///
/// Flow:
///   Phase A — One emotion at a time (8 steps).
///     • Large emoji + emotion name.
///     • Progress label "Emotion 1 of 8".
///     • 12-colour palette below.
///     • Picking a colour fills the emoji circle with that colour (live preview).
///     • "Next →" button advances; Back arrow goes to previous emotion.
///   Phase B — Summary screen.
///     • 2×4 grid showing all 8 emotions with their chosen colours.
///     • "Save & Continue" button persists colours + calls [onFinished].
class MyColoursScreen extends ConsumerStatefulWidget {
  final bool isOnboarding;
  final VoidCallback? onFinished;

  const MyColoursScreen({
    super.key,
    this.isOnboarding = false,
    this.onFinished,
  });

  @override
  ConsumerState<MyColoursScreen> createState() => _MyColoursScreenState();
}

class _MyColoursScreenState extends ConsumerState<MyColoursScreen>
    with TickerProviderStateMixin {

  static const List<Color> _palette = [
    Color(0xFFEF4444), // Red
    Color(0xFFF97316), // Orange
    Color(0xFFFFE66D), // Yellow
    Color(0xFF22C55E), // Green
    Color(0xFF4ECDC4), // Teal
    Color(0xFF60A5FA), // Sky Blue
    Color(0xFF74B9FF), // Light Blue
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFFFF7EB3), // Rose
    Color(0xFFFF9F43), // Amber
    Color(0xFF9CA3AF), // Gray
  ];

  int _currentIndex = 0;
  bool _showSummary = false;
  bool _isSaving = false;

  // One colour choice per emotion (index-aligned with emotions list)
  List<Color?> _picks = [];

  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOutBack),
    );
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onColorPicked(Color color, List<Emotion> emotions) {
    setState(() => _picks[_currentIndex] = color);
    // Bounce the emoji
    _bounceCtrl.forward(from: 0);
  }

  void _goNext(int total) {
    if (_currentIndex < total - 1) {
      _fadeCtrl.forward(from: 0);
      setState(() {
        _currentIndex++;
      });
    } else {
      // All done — show summary
      _fadeCtrl.forward(from: 0);
      setState(() => _showSummary = true);
    }
  }

  void _goBack() {
    if (_showSummary) {
      _fadeCtrl.forward(from: 0);
      setState(() => _showSummary = false);
      return;
    }
    if (_currentIndex > 0) {
      _fadeCtrl.forward(from: 0);
      setState(() => _currentIndex--);
    } else if (!widget.isOnboarding) {
      Navigator.pop(context);
    }
  }

  Future<void> _saveAndFinish(List<Emotion> emotions) async {
    setState(() => _isSaving = true);
    try {
      // Merge picks into emotion list
      final updated = emotions.asMap().entries.map((entry) {
        final pick = _picks[entry.key];
        return pick != null ? entry.value.copyWith(color: pick) : entry.value;
      }).toList();

      await ref.read(emotionServiceProvider.notifier).saveAllColors(updated);
      await EmotionService.markAllAssigned();
    } catch (e) {
      debugPrint('MyColoursScreen._saveAndFinish: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
    if (mounted) widget.onFinished?.call();
  }

  TextStyle _cute({double size = 20, FontWeight weight = FontWeight.w700, Color color = Colors.white}) =>
      GoogleFonts.baloo2(fontSize: size, fontWeight: weight, color: color);

  @override
  Widget build(BuildContext context) {
    final emotions = ref.watch(emotionServiceProvider);
    if (emotions.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Initialise picks from current state (one per emotion)
    if (_picks.length != emotions.length) {
      _picks = emotions.map((e) => e.color).toList();
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE0C3FC), Color(0xFF8EC5FC), Color(0xFFFBC2EB)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: _showSummary
                ? _buildSummary(emotions)
                : _buildPickerPage(emotions),
          ),
        ),
      ),
    );
  }

  // ── Phase A: Picker ──────────────────────────────────────────────

  Widget _buildPickerPage(List<Emotion> emotions) {
    if (_currentIndex >= emotions.length) _currentIndex = 0;
    final emotion = emotions[_currentIndex];
    final displayColor = _picks[_currentIndex] ?? emotion.color;
    final total = emotions.length;
    final canGoNext = _picks[_currentIndex] != null;

    return Column(
      children: [
        // ── Top bar ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(
            children: [
              if (_currentIndex > 0 || !widget.isOnboarding)
                IconButton(
                  onPressed: _goBack,
                  icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70, size: 26),
                )
              else
                const SizedBox(width: 48),
              const Spacer(),
              Text(
                'My Colours',
                style: _cute(size: 26, weight: FontWeight.w900, color: const Color(0xFF1B2541)),
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
        ),

        // ── Progress: "Emotion X of 8" ───────────────────────────
        const SizedBox(height: 6),
        Text(
          'Emotion ${_currentIndex + 1} of $total',
          style: _cute(size: 16, weight: FontWeight.w600,
              color: Colors.black.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 6),
        _buildProgressBar(total),
        const SizedBox(height: 10),

        // ── Main area ────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Animated emotion display
                _buildEmotionDisplay(emotion, displayColor),

                Text(
                  'Pick a colour for ${emotion.name}',
                  style: _cute(size: 22, weight: FontWeight.w600, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),

                // Colour palette
                _buildPalette(emotion, emotions),

                // Next button
                SizedBox(
                  width: 280,
                  child: ElevatedButton.icon(
                    onPressed: canGoNext ? () => _goNext(total) : null,
                    icon: Icon(
                      _currentIndex < total - 1
                          ? Icons.arrow_forward_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 24,
                    ),
                    label: Text(
                      _currentIndex < total - 1 ? 'Next →' : 'See Summary',
                      style: _cute(size: 20, weight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canGoNext
                          ? displayColor
                          : Colors.grey.shade300,
                      disabledBackgroundColor: Colors.grey.shade200,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22)),
                      elevation: canGoNext ? 6 : 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(int total) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(total, (i) {
          final done = _picks[i] != null;
          final active = i == _currentIndex;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: done
                    ? (_picks[i] ?? Colors.green)
                    : (active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.35)),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmotionDisplay(Emotion emotion, Color displayColor) {
    return AnimatedBuilder(
      animation: _bounceAnim,
      builder: (_, child) => Transform.scale(scale: _bounceAnim.value, child: child),
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: displayColor.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: displayColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: displayColor.withValues(alpha: 0.55),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Center(
                child: Text(emotion.emoji, style: const TextStyle(fontSize: 70)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              emotion.name,
              style: _cute(size: 36, weight: FontWeight.w900, color: Colors.black87),
            ),
            Text(
              emotion.valence == 'positive' ? '😊 Positive' : '💙 Negative',
              style: _cute(size: 14, weight: FontWeight.w500,
                  color: emotion.valence == 'positive'
                      ? const Color(0xFF10B981)
                      : const Color(0xFF6366F1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPalette(Emotion emotion, List<Emotion> emotions) {
    final currentPick = _picks[_currentIndex];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        alignment: WrapAlignment.center,
        children: _palette.map((c) {
          final isChosen = currentPick?.toARGB32() == c.toARGB32();
          return GestureDetector(
            onTap: () => _onColorPicked(c, emotions),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isChosen ? 62 : 52,
              height: isChosen ? 62 : 52,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isChosen ? Colors.black87 : Colors.white,
                  width: isChosen ? 3.5 : 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: c.withValues(alpha: isChosen ? 0.6 : 0.3),
                    blurRadius: isChosen ? 12 : 5,
                  ),
                ],
              ),
              child: isChosen
                  ? const Icon(Icons.check_rounded, color: Colors.black87, size: 26)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Phase B: Summary ─────────────────────────────────────────────

  Widget _buildSummary(List<Emotion> emotions) {
    final allDone = _picks.every((p) => p != null);

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.white70, size: 26),
              ),
              const Spacer(),
              Text('Your Colours! 🎨',
                  style: _cute(size: 28, weight: FontWeight.w900,
                      color: const Color(0xFF1B2541))),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Here are the colours you chose for each feeling',
          style: _cute(size: 15, weight: FontWeight.w500,
              color: Colors.black.withValues(alpha: 0.6)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // 2×4 grid
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: emotions.length,
              itemBuilder: (context, i) {
                final e = emotions[i];
                final c = _picks[i] ?? e.color;
                return GestureDetector(
                  onTap: () {
                    // Tap a summary card to go back and re-pick that colour
                    _fadeCtrl.forward(from: 0);
                    setState(() {
                      _currentIndex = i;
                      _showSummary = false;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: c.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: Center(
                            child: Text(e.emoji,
                                style: const TextStyle(fontSize: 28)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          e.name,
                          style: _cute(size: 13, weight: FontWeight.w700,
                              color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Save button
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: SizedBox(
            width: 320,
            child: ElevatedButton.icon(
              onPressed: (allDone && !_isSaving)
                  ? () => _saveAndFinish(emotions)
                  : null,
              icon: _isSaving
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Icon(Icons.check_circle_rounded, size: 26),
              label: Text(
                _isSaving ? 'Saving...' : 'Save & Continue 🚀',
                style: _cute(size: 22, weight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: allDone
                    ? const Color(0xFF10B981)
                    : Colors.grey.shade300,
                disabledBackgroundColor: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                elevation: allDone ? 8 : 0,
                shadowColor:
                    const Color(0xFF10B981).withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
