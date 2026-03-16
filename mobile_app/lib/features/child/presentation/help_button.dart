import 'package:flutter/material.dart';
import '../services/instructions_service.dart';
import 'instructions_overlay.dart';

/// UCD015 – Floating "Help (?)" button for in-game instruction access.
///
/// Drop this widget into any activity screen's `Stack` or `AppBar`
/// actions. When tapped it shows the [InstructionsOverlay] with a
/// "Close" dismiss label.
///
/// If the activity has no instructions defined (alt-flow) the button
/// is hidden automatically.
class HelpButton extends StatelessWidget {
  /// The id of the current activity (matches keys in [InstructionsService]).
  final String activityId;

  /// Emoji for the overlay title.
  final String activityEmoji;

  /// Human-readable name shown in the overlay subtitle.
  final String activityName;

  const HelpButton({
    super.key,
    required this.activityId,
    this.activityEmoji = '❓',
    this.activityName = 'Activity',
  });

  @override
  Widget build(BuildContext context) {
    final service = InstructionsService.instance;

    // Alt-flow: no instructions defined → hide the button entirely.
    if (!service.hasInstructions(activityId)) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        final text = service.getInstructions(activityId)!;
        showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (_) => InstructionsOverlay(
            emoji: activityEmoji,
            activityName: activityName,
            instructionText: text,
            dismissLabel: 'Close',
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFF6B21A8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.help_outline_rounded,
          color: Colors.white,
          size: 31,
        ),
      ),
    );
  }
}
