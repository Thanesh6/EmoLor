/// UCD013 – Holds runtime state for a single activity session.
///
/// Created by [ActivityLauncherScreen] after consulting the Adaptive
/// Sensory Engine. Passed into the actual activity widget so it can
/// use the difficulty parameters and session timer.
class ActivitySession {
  /// Unique id of the activity being played.
  final String activityId;

  /// Difficulty level computed by the Adaptive Sensory Engine.
  /// 1 = easiest, 2 = medium, 3 = hardest.
  final int difficultyLevel;

  /// Speed multiplier (lower = slower = easier). Default 1.0.
  final double speedMultiplier;

  /// Number of items / rounds the activity should present.
  final int itemCount;

  /// Whether instructions have already been shown for this activity
  /// (persisted in SharedPreferences). When `true` the launcher
  /// skipped the instructions dialog.
  final bool instructionsAlreadySeen;

  /// Timestamp when the activity was initialized.
  final DateTime startedAt;

  const ActivitySession({
    required this.activityId,
    this.difficultyLevel = 1,
    this.speedMultiplier = 1.0,
    this.itemCount = 5,
    this.instructionsAlreadySeen = false,
    required this.startedAt,
  });

  /// Elapsed seconds since the session started.
  int get elapsedSeconds => DateTime.now().difference(startedAt).inSeconds;

  @override
  String toString() => 'ActivitySession(id=$activityId, diff=$difficultyLevel, '
      'speed=$speedMultiplier, items=$itemCount, '
      'elapsed=${elapsedSeconds}s)';
}
