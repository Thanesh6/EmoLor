import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/emotion_service.dart';
import '../domain/models/emotion.dart';

/// UCD017 - My Colours: Plutchik's 8 Primary Emotions
///
/// One-at-a-time emotion view with large emoji + name.
/// Left/right arrows to navigate. Colour picker always visible.
/// No time limits, no penalties, gentle experience.
class MyColoursScreen extends ConsumerStatefulWidget {
  /// When true, screen runs as a Phase-2 onboarding step:
  ///   * back button hidden (forces child to pick)
  ///   * after the child taps Save on the LAST emotion, [onFinished] fires
  ///     automatically — there is no separate "I'm done!" button.
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

class _MyColoursScreenState extends ConsumerState<MyColoursScreen> {
  // Core rainbow + neutrals so children have enough range to express each
  // feeling without being overwhelmed by a huge grid.
  static const List<_PaletteEntry> _palette = [
    _PaletteEntry(Color(0xFFEF4444), 'Red'),
    _PaletteEntry(Color(0xFFF97316), 'Orange'),
    _PaletteEntry(Color(0xFFFFE66D), 'Yellow'),
    _PaletteEntry(Color(0xFF22C55E), 'Green'),
    _PaletteEntry(Color(0xFF4ECDC4), 'Teal'),
    _PaletteEntry(Color(0xFF74B9FF), 'Blue'),
    _PaletteEntry(Color(0xFF8B5CF6), 'Purple'),
    _PaletteEntry(Color(0xFFEC4899), 'Pink'),
    _PaletteEntry(Color(0xFF8B4513), 'Brown'),
    _PaletteEntry(Color(0xFF9CA3AF), 'Gray'),
    _PaletteEntry(Color(0xFF000000), 'Black'),
  ];

  /// Index of the currently displayed emotion (0..7).
  int _currentIndex = 0;

  /// Live preview colour the child is considering (null = current saved).
  Color? _previewColour;

  /// Indices whose colour the child has saved in this session — drives
  /// the green progress dots up top.
  final Set<int> _savedIndices = <int>{};

  /// Set briefly when the child taps Save with a colour that another
  /// emotion already owns. Flashes the Save button red so they know to
  /// pick a different swatch. Auto-clears after a short delay or as soon
  /// as a new colour is tapped.
  bool _duplicateReject = false;

  TextStyle _cute({
    double size = 20,
    FontWeight weight = FontWeight.w700,
    Color color = Colors.white,
  }) =>
      GoogleFonts.baloo2(fontSize: size, fontWeight: weight, color: color);

  void _goNext(int total) {
    setState(() {
      _currentIndex = (_currentIndex + 1) % total;
      _previewColour = null;
    });
  }

  void _goPrev(int total) {
    setState(() {
      _currentIndex = (_currentIndex - 1 + total) % total;
      _previewColour = null;
    });
  }

  Future<void> _saveColour(Emotion emotion, {required int total}) async {
    if (_previewColour == null) return;

    final svc = ref.read(emotionServiceProvider.notifier);
    final dup = svc.findDuplicateColour(_previewColour!, excludeId: emotion.id);

    // Reject duplicates outright — every one of the 8 emotions must get
    // its OWN colour before the child can move on. Flash the Save button
    // red as an inline cue instead of slamming a top-banner down.
    if (dup != null) {
      setState(() {
        _duplicateReject = true;
      });
      // Auto-clear the red state after a short beat so the button
      // relaxes back to its normal colour on its own.
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() => _duplicateReject = false);
      });
      return;
    }

    await svc.updateEmotionColor(emotion.id, _previewColour!);

    if (!mounted) return;

    // Mark this emotion as saved so its progress dot turns green.
    _savedIndices.add(_currentIndex);

    // In Phase-2 onboarding, finish ONLY once every emotion has a
    // unique saved colour. Otherwise, hop to the next emotion that still
    // needs one so the child keeps filling the set in order, regardless
    // of which index they started tweaking.
    if (widget.isOnboarding) {
      if (_savedIndices.length >= total && widget.onFinished != null) {
        widget.onFinished!();
        return;
      }

      int next = _currentIndex;
      for (int step = 1; step <= total; step++) {
        final candidate = (_currentIndex + step) % total;
        if (!_savedIndices.contains(candidate)) {
          next = candidate;
          break;
        }
      }
      setState(() {
        _previewColour = null;
        _currentIndex = next;
      });
      return;
    }

    // Non-onboarding (standalone) view stays put so the child can tweak
    // a single colour without auto-advancing.
    setState(() {
      _previewColour = null;
    });
  }

  // ------------------- BUILD -------------------

  @override
  Widget build(BuildContext context) {
    final emotions = ref.watch(emotionServiceProvider);
    if (emotions.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentIndex >= emotions.length) _currentIndex = 0;
    final emotion = emotions[_currentIndex];
    final displayColour = _previewColour ?? emotion.color;

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
          child: Column(
            children: [
              _buildHeader(),
              if (widget.isOnboarding) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Give every feeling its own colour — all 8 must be different to finish.',
                    textAlign: TextAlign.center,
                    style: _cute(
                      size: 16,
                      weight: FontWeight.w600,
                      color: Colors.black.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              // Progress dots
              _buildProgressDots(emotions.length),
              const SizedBox(height: 8),
              // Main content: sized to fit the remaining viewport so nothing
              // scrolls — tablet real-estate is generous, this just snaps
              // the emotion card + picker into one visible frame.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Emotion card with arrows
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildArrowButton(Icons.chevron_left_rounded,
                              () => _goPrev(emotions.length)),
                          const SizedBox(width: 16),
                          _buildEmotionDisplay(emotion, displayColour),
                          const SizedBox(width: 16),
                          _buildArrowButton(Icons.chevron_right_rounded,
                              () => _goNext(emotions.length)),
                        ],
                      ),
                      // Instruction
                      Text(
                        'Pick a colour for ${emotion.name}',
                        style: _cute(
                            size: 24,
                            weight: FontWeight.w600,
                            color: Colors.black87),
                      ),
                      // Colour picker
                      _buildColourPicker(emotion),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Centered title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'My Colors',
                style: _cute(
                    size: 54,
                    weight: FontWeight.w900,
                    color: const Color(0xFF1B2541)),
              ),
              const SizedBox(width: 8),
              const Text('\u{1F3A8}', style: TextStyle(fontSize: 46)),
            ],
          ),
          // Back button pinned to left (hidden during Phase-2 onboarding)
          if (!widget.isOnboarding)
            Positioned(
              left: 12,
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
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Color(0xFF6B21A8), size: 31),
                ),
              ),
            ),
          // No "I'm done!" button — onboarding auto-finishes after the
          // final emotion's colour is saved.
        ],
      ),
    );
  }

  Widget _buildProgressDots(int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i == _currentIndex;
        final isSaved = _savedIndices.contains(i);
        // Saved → green. Active (but unsaved) → solid white. Idle → faded.
        final Color dotColor = isSaved
            ? const Color(0xFF22C55E)
            : (isActive ? Colors.white : Colors.white.withValues(alpha: 0.4));
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 12,
          height: 12,
          decoration: BoxDecoration(
            color: dotColor,
            borderRadius: BorderRadius.circular(5),
            boxShadow: isSaved
                ? [
                    BoxShadow(
                      color:
                          const Color(0xFF22C55E).withValues(alpha: 0.45),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildArrowButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3),
          shape: BoxShape.circle,
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 42),
      ),
    );
  }

  Widget _buildEmotionDisplay(Emotion emotion, Color displayColour) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(38),
        boxShadow: [
          BoxShadow(
            color: displayColour.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Big coloured circle with emoji
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: displayColour,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: displayColour.withValues(alpha: 0.5),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Center(
              child: Text(emotion.emoji, style: const TextStyle(fontSize: 74)),
            ),
          ),
          const SizedBox(height: 10),
          Text(emotion.name, style: _cute(size: 38, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildColourPicker(Emotion emotion) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Colour circles
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: _palette.map((entry) {
              final isChosen =
                  _previewColour?.toARGB32() == entry.color.toARGB32();
              final isCurrent =
                  emotion.color.toARGB32() == entry.color.toARGB32() &&
                      _previewColour == null;
              return GestureDetector(
                onTap: () => setState(() {
                  _previewColour = entry.color;
                  _duplicateReject = false;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isChosen ? 64 : 56,
                  height: isChosen ? 64 : 56,
                  decoration: BoxDecoration(
                    color: entry.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (isChosen || isCurrent)
                          ? Colors.black87
                          : Colors.white,
                      width: (isChosen || isCurrent) ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: entry.color.withValues(alpha: 0.4),
                        blurRadius: isChosen ? 10 : 4,
                      ),
                    ],
                  ),
                  child: (isChosen || isCurrent)
                      ? const Icon(Icons.check_rounded,
                          color: Colors.black87, size: 28)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          // Save button — flashes red when the picked colour is already
          // taken by another emotion, otherwise mirrors the preview swatch.
          SizedBox(
            width: 240,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: _duplicateReject
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDC2626)
                              .withValues(alpha: 0.55),
                          blurRadius: 14,
                        ),
                      ],
                    )
                  : const BoxDecoration(),
              child: ElevatedButton.icon(
                onPressed: _previewColour != null
                    ? () => _saveColour(emotion,
                        total: ref.read(emotionServiceProvider).length)
                    : null,
                icon: Text(
                  _duplicateReject ? '\u274C' : '\u{1F4BE}',
                  style: const TextStyle(fontSize: 24),
                ),
                label: Text('Save',
                    style: _cute(
                        size: 24,
                        color: _previewColour != null
                            ? Colors.white
                            : Colors.grey)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _duplicateReject
                      ? const Color(0xFFDC2626)
                      : (_previewColour ?? Colors.grey.shade300),
                  disabledBackgroundColor: Colors.grey.shade200,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22)),
                  elevation: _previewColour != null ? 4 : 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteEntry {
  final Color color;
  final String label;
  const _PaletteEntry(this.color, this.label);
}

