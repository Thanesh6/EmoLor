import 'package:flutter/material.dart';
import '../../../core/services/star_service.dart';
import '../models/activity_save_state.dart';
import '../models/completion_record.dart';
import '../services/activity_progress_service.dart';
import '../services/completion_service.dart';
import 'exit_activity_dialog.dart';

/// UCD016 – Shared helper for the "Exit Activity" flow.
///
/// Call [handleExitActivity] from any game screen's back button.
/// It pauses the timer (conceptually), shows the exit prompt, and
/// either saves progress + pops or resumes the activity.
///
/// Usage:
/// ```dart
/// onTap: () => ActivityExitHandler.handleExitActivity(
///   context: context,
///   activityId: 'game_emotion_path',
///   activityEmoji: '🛤️',
///   elapsedSeconds: _stopwatch.elapsedSeconds,
///   buildProgressData: () => {'level': _level, 'score': _score},
/// );
/// ```
class ActivityExitHandler {
  ActivityExitHandler._(); // static-only

  static final ActivityProgressService _progressService =
      ActivityProgressService();

  /// Show the exit prompt and handle save-or-resume.
  ///
  /// * [context] – the current `BuildContext`.
  /// * [activityId] – e.g. `'game_emotion_path'`.
  /// * [activityEmoji] – shown in the dialog.
  /// * [elapsedSeconds] – seconds the child has played so far.
  /// * [buildProgressData] – callback that returns a `Map<String, dynamic>`
  ///   capturing activity-specific state (level, score, strokes, page…).
  ///   Called only when the child chooses "Stop".
  /// * [onBeforeExit] – optional callback executed right before popping
  ///   (e.g. to stop timers, save garden items, etc.).
  /// * [difficultyLevel] / [speedMultiplier] – from the session.
  static Future<void> handleExitActivity({
    required BuildContext context,
    required String activityId,
    String activityEmoji = '🎮',
    String activityName = '',
    int elapsedSeconds = 0,
    Map<String, dynamic> Function()? buildProgressData,
    VoidCallback? onBeforeExit,
    int difficultyLevel = 1,
    double speedMultiplier = 1.0,
    String? starGameKey,
    int sessionStars = 0,
  }) async {
    // Step 2: Pause – conceptually the timer is paused while the dialog
    // is up (the activity loop is blocked on `await showDialog`).

    // Step 3: Show visual confirmation prompt.
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExitActivityDialog(activityEmoji: activityEmoji),
    );

    if (shouldExit != true) {
      // Alt-flow: child tapped "Keep Playing" → resume (dialog closes).
      return;
    }

    // Accumulate session stars to persistent total before saving.
    if (starGameKey != null && sessionStars > 0) {
      await StarService.addStars(starGameKey, sessionStars);
    }

    // Save a CompletionRecord so the caregiver dashboard can track activity
    if (sessionStars > 0 || elapsedSeconds > 0) {
      final name = activityName.isNotEmpty ? activityName : activityId;
      await CompletionService.save(CompletionRecord(
        activityId: activityId,
        activityName: name,
        starsEarned: sessionStars,
        scoreValue: sessionStars * 20, // approximate score from stars
        scoreMax: 100,
        timeSpentSeconds: elapsedSeconds,
        completedAt: DateTime.now(),
      ));
    }

    // Step 5: Save current activity state to local storage.
    final progressData = buildProgressData?.call() ?? const {};
    final saveState = ActivitySaveState(
      activityId: activityId,
      savedAt: DateTime.now(),
      elapsedSeconds: elapsedSeconds,
      difficultyLevel: difficultyLevel,
      speedMultiplier: speedMultiplier,
      progressData: progressData,
    );
    await _progressService.saveProgress(saveState);

    // Optional pre-exit hook (stop timers, persist extra state, etc.)
    onBeforeExit?.call();

    // Step 6: Return the child to the Browse Activities screen.
    // `Navigator.pop` takes us back to wherever the activity was pushed
    // from (Browse → Launcher → Activity, so we pop twice if launcher
    // used pushReplacement — in that case one pop suffices).
    if (context.mounted) {
      Navigator.pop(context);
    }
  }
}
