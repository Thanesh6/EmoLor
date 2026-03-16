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
  const MyColoursScreen({super.key});

  @override
  ConsumerState<MyColoursScreen> createState() => _MyColoursScreenState();
}

class _MyColoursScreenState extends ConsumerState<MyColoursScreen> {
  // 12 soft, autism-friendly palette colours
  static const List<_PaletteEntry> _palette = [
    _PaletteEntry(Color(0xFFEF4444), 'Red'),
    _PaletteEntry(Color(0xFFF97316), 'Orange'),
    _PaletteEntry(Color(0xFFFBBF24), 'Amber'),
    _PaletteEntry(Color(0xFFFFE66D), 'Yellow'),
    _PaletteEntry(Color(0xFF84CC16), 'Lime'),
    _PaletteEntry(Color(0xFF22C55E), 'Green'),
    _PaletteEntry(Color(0xFF4ECDC4), 'Teal'),
    _PaletteEntry(Color(0xFF06B6D4), 'Cyan'),
    _PaletteEntry(Color(0xFF74B9FF), 'Sky'),
    _PaletteEntry(Color(0xFF8B5CF6), 'Violet'),
    _PaletteEntry(Color(0xFFBB6BD9), 'Purple'),
    _PaletteEntry(Color(0xFFEC4899), 'Pink'),
  ];

  /// Index of the currently displayed emotion (0..7).
  int _currentIndex = 0;

  /// Live preview colour the child is considering (null = current saved).
  Color? _previewColour;

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

  Future<void> _saveColour(Emotion emotion) async {
    if (_previewColour == null) return;

    final svc = ref.read(emotionServiceProvider.notifier);
    final dup = svc.findDuplicateColour(_previewColour!, excludeId: emotion.id);

    if (dup != null) {
      final proceed = await _showDuplicateWarning(dup);
      if (proceed != true) return;
    }

    await svc.updateEmotionColor(emotion.id, _previewColour!);

    if (!mounted) return;

    _showTopBanner(
      '${emotion.emoji}  ${emotion.name} colour saved!',
      _previewColour!,
    );
    setState(() => _previewColour = null);
  }

  void _showTopBanner(String message, Color bgColor) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _TopBanner(
        message: message,
        bgColor: bgColor,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  Future<bool?> _showDuplicateWarning(Emotion other) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(29)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 432),
          child: Padding(
            padding: const EdgeInsets.all(29),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('\u{1F914}', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 10),
                Text('Same Colour',
                    style: _cute(size: 26, color: Colors.black87)),
                const SizedBox(height: 10),
                Text(
                  'You already used this colour for ${other.emoji} ${other.name}.\nUse it again?',
                  textAlign: TextAlign.center,
                  style: _cute(
                      size: 18, weight: FontWeight.w500, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Pick Another',
                            style: _cute(size: 18, color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _previewColour,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(19)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text("Yes!", style: _cute(size: 18)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
              const SizedBox(height: 20),
              // Progress dots
              _buildProgressDots(emotions.length),
              const SizedBox(height: 12),
              // Main content: emotion display + colour picker
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      // Emotion card with arrows
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Left arrow
                          _buildArrowButton(Icons.chevron_left_rounded,
                              () => _goPrev(emotions.length)),
                          const SizedBox(width: 16),
                          // Big emotion display
                          _buildEmotionDisplay(emotion, displayColour),
                          const SizedBox(width: 16),
                          // Right arrow
                          _buildArrowButton(Icons.chevron_right_rounded,
                              () => _goNext(emotions.length)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Instruction
                      Text(
                        'Pick a colour for ${emotion.name}',
                        style: _cute(
                            size: 26,
                            weight: FontWeight.w600,
                            color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
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
          // Back button pinned to left
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
        ],
      ),
    );
  }

  Widget _buildProgressDots(int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i == _currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 12,
          height: 12,
          decoration: BoxDecoration(
            color:
                isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(5),
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
      width: 350,
      height: 350,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(45),
        boxShadow: [
          BoxShadow(
            color: displayColour.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Big coloured circle with emoji
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 175,
            height: 175,
            decoration: BoxDecoration(
              color: displayColour,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: displayColour.withValues(alpha: 0.5),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Center(
              child: Text(emotion.emoji, style: const TextStyle(fontSize: 93)),
            ),
          ),
          const SizedBox(height: 14),
          Text(emotion.name, style: _cute(size: 49, color: Colors.black87)),
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
                onTap: () => setState(() => _previewColour = entry.color),
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
          // Save button
          SizedBox(
            width: 240,
            child: ElevatedButton.icon(
              onPressed:
                  _previewColour != null ? () => _saveColour(emotion) : null,
              icon: const Text('\u{1F4BE}', style: TextStyle(fontSize: 24)),
              label: Text('Save',
                  style: _cute(
                      size: 24,
                      color:
                          _previewColour != null ? Colors.white : Colors.grey)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _previewColour ?? Colors.grey.shade300,
                disabledBackgroundColor: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
                elevation: _previewColour != null ? 4 : 0,
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

/// Slides in from the top, holds for 2 s, then slides out.
class _TopBanner extends StatefulWidget {
  final String message;
  final Color bgColor;
  final VoidCallback onDone;

  const _TopBanner({
    required this.message,
    required this.bgColor,
    required this.onDone,
  });

  @override
  State<_TopBanner> createState() => _TopBannerState();
}

class _TopBannerState extends State<_TopBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 2200), () async {
      if (mounted) {
        await _ctrl.reverse();
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine text color based on background luminance
    final textColor =
        widget.bgColor.computeLuminance() > 0.4 ? Colors.black87 : Colors.white;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slide,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: widget.bgColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: widget.bgColor.withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
