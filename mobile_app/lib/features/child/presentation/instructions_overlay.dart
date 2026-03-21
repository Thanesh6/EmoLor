import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/instructions_service.dart';

/// UCD015 – Full-screen instructions overlay.
///
/// Presented **before** the activity starts (auto-trigger from the
/// launcher) and **during** gameplay when the child taps the Help (?)
/// button.
///
/// Features:
///   • Visual: activity emoji, animated entrance, large readable text.
///   • Audible: automatically reads the instruction aloud via TTS
///     (based on accessibility settings — TTS is opt-in via the
///     speaker icon toggle).
///   • "Start" / "Close" button to dismiss.
class InstructionsOverlay extends StatefulWidget {
  /// Emoji shown at the top of the overlay.
  final String emoji;

  /// Human-readable activity name.
  final String activityName;

  /// Instruction text. If `null` the overlay should not be shown
  /// (caller should check [InstructionsService.hasInstructions] first).
  final String instructionText;

  /// Label on the dismiss button.
  /// Use `"Let's Go!"` before an activity starts and `"Close"` when
  /// opened from the Help button mid-game.
  final String dismissLabel;

  const InstructionsOverlay({
    super.key,
    required this.emoji,
    required this.activityName,
    required this.instructionText,
    this.dismissLabel = "Let's Go! 🚀",
  });

  @override
  State<InstructionsOverlay> createState() => _InstructionsOverlayState();
}

class _InstructionsOverlayState extends State<InstructionsOverlay>
    with SingleTickerProviderStateMixin {
  final InstructionsService _ttsService = InstructionsService.instance;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  bool _ttsEnabled = true; // auto-speak on open by default

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();

    // Auto-speak the instruction (UCD015 step 2 – audible)
    if (_ttsEnabled) {
      _ttsService.speak(widget.instructionText);
    }
  }

  @override
  void dispose() {
    _ttsService.stop();
    _animController.dispose();
    super.dispose();
  }

  void _toggleTts() {
    setState(() => _ttsEnabled = !_ttsEnabled);
    if (_ttsEnabled) {
      _ttsService.speak(widget.instructionText);
    } else {
      _ttsService.stop();
      // Immediately remove highlight when sound is turned off
      _ttsService.wordStart.value = -1;
      _ttsService.wordEnd.value = -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Emoji ───────────────────────────────────────────────
                Text(widget.emoji, style: const TextStyle(fontSize: 63)),
                const SizedBox(height: 10),

                // ── Title ───────────────────────────────────────────────
                Text(
                  'How to Play',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                      fontSize: 29, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.activityName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: Colors.black45),
                ),
                const SizedBox(height: 18),

                // ── Instruction text (visual + karaoke highlight) ────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F0FF),
                    borderRadius: BorderRadius.circular(18),
                    border:
                        Border.all(color: const Color(0xFFDDD6FE), width: 2),
                  ),
                  child: ValueListenableBuilder<int>(
                    valueListenable: _ttsService.wordStart,
                    builder: (_, start, __) {
                      return ValueListenableBuilder<int>(
                        valueListenable: _ttsService.wordEnd,
                        builder: (_, end, __) {
                          return _buildHighlightedText(
                            widget.instructionText,
                            start,
                            end,
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),

                // ── TTS toggle row ──────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _toggleTts,
                      icon: Icon(
                        _ttsEnabled
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        color: const Color(0xFF8B5CF6),
                        size: 34,
                      ),
                      tooltip: _ttsEnabled ? 'Mute' : 'Read aloud',
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _ttsEnabled ? 'Reading aloud' : 'Sound off',
                      style: GoogleFonts.baloo2(
                          fontSize: 16, color: Colors.black45),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Dismiss button (UCD015 step 3) ──────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      _ttsService.stop();
                      Navigator.pop(context);
                    },
                    child: Text(
                      widget.dismissLabel,
                      style: GoogleFonts.baloo2(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
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

  Widget _buildHighlightedText(String text, int start, int end) {
    if (start < 0 ||
        end < 0 ||
        start >= text.length ||
        end > text.length ||
        start >= end) {
      // Default: no active word, render normally but centered
      return Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.baloo2(
            fontSize: 20, height: 1.5, color: Colors.black87),
      );
    }

    final String before = text.substring(0, start);
    final String highlight = text.substring(start, end);
    final String after = text.substring(end);

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: GoogleFonts.baloo2(
            fontSize: 20, height: 1.5, color: Colors.black87),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: highlight,
            style: const TextStyle(
              color: Color(0xFF6B21A8),
              fontWeight: FontWeight.w800,
              backgroundColor: Color(0xFFE9D5FF),
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }
}
