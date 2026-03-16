import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// UCD016 – Child-friendly exit confirmation prompt.
///
/// Shown when the child taps Back / Exit during an active activity.
/// Two large, colourful options:
///   • **Keep Playing** (green) – dismisses the dialog, returns `false`.
///   • **Stop** (red) – returns `true` so the caller can save & pop.
///
/// Returns `true` for Stop, `false` for Keep Playing, `null` if dismissed.
class ExitActivityDialog extends StatelessWidget {
  /// Emoji of the current activity (displayed at the top).
  final String activityEmoji;

  const ExitActivityDialog({
    super.key,
    this.activityEmoji = '🎮',
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(34)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 384),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(29, 34, 29, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji + title
              Text(activityEmoji, style: const TextStyle(fontSize: 62)),
              const SizedBox(height: 12),
              Text(
                'Wait!',
                style: GoogleFonts.baloo2(
                    fontSize: 34, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Do you want to keep playing\nor stop for now?',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(fontSize: 19, color: Colors.black54),
              ),
              const SizedBox(height: 29),

              // ── "Keep Playing" button (green – alt-flow: cancel exit) ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 34),
                  label: Text(
                    'Keep Playing',
                    style: GoogleFonts.baloo2(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)),
                    padding: const EdgeInsets.symmetric(vertical: 17),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ),
              const SizedBox(height: 14),

              // ── "Stop" button (red – main flow: save & exit) ───────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.stop_rounded,
                      color: Colors.white, size: 34),
                  label: Text(
                    'Stop',
                    style: GoogleFonts.baloo2(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)),
                    padding: const EdgeInsets.symmetric(vertical: 17),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
