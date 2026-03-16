import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/activity_item.dart';
import '../models/activity_save_state.dart';

/// UCD014 – Child-friendly prompt shown when an in-progress activity is tapped.
///
/// Offers two choices:
///   • **Continue** – load saved state and resume where the child left off.
///   • **Restart** – discard saved state, start fresh (alt-flow 1).
///
/// Returns `true` for Continue, `false` for Restart, or `null` if dismissed.
class ContinueRestartDialog extends StatelessWidget {
  final ActivityItem activity;
  final ActivitySaveState savedState;

  const ContinueRestartDialog({
    super.key,
    required this.activity,
    required this.savedState,
  });

  /// Helper to display elapsed time in a child-friendly way.
  String _friendlyElapsed() {
    final s = savedState.elapsedSeconds;
    if (s < 60) return '$s seconds';
    final m = s ~/ 60;
    final rem = s % 60;
    if (rem == 0) return '$m min';
    return '$m min $rem sec';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emoji + title
            Text(activity.emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 10),
            Text(
              'Welcome back!',
              style:
                  GoogleFonts.baloo2(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'You played ${_friendlyElapsed()} last time.',
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Text(
              'Would you like to keep going\nor start over?',
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(fontSize: 15, color: Colors.black45),
            ),
            const SizedBox(height: 24),

            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                label: Text(
                  'Continue ▶',
                  style: GoogleFonts.baloo2(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(context, true),
              ),
            ),
            const SizedBox(height: 12),

            // Restart button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon:
                    const Icon(Icons.refresh_rounded, color: Color(0xFF8B5CF6)),
                label: Text(
                  'Start Over 🔄',
                  style: GoogleFonts.baloo2(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8B5CF6)),
                ),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22)),
                  side: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.pop(context, false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
