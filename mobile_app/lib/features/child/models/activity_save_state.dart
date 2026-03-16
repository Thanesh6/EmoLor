import 'dart:convert';

/// UCD014 – Persisted save-state for an in-progress activity.
///
/// Stored as JSON in SharedPreferences so a child can resume where
/// they left off. Fields intentionally kept simple so that any
/// activity-specific progress data (drawing strokes, story page,
/// current game level, etc.) is captured in [progressData].
class ActivitySaveState {
  /// Activity id that this state belongs to.
  final String activityId;

  /// UTC timestamp when this state was last saved.
  final DateTime savedAt;

  /// Number of seconds the child had already spent before pausing.
  /// Used to resume the session timer at the correct offset.
  final int elapsedSeconds;

  /// Difficulty level the child was playing at when they paused.
  final int difficultyLevel;

  /// Speed multiplier from the Adaptive Engine (preserved on resume).
  final double speedMultiplier;

  /// Free-form map holding activity-specific progress.
  /// E.g. `{'currentPage': 3}` for stories, `{'level': 2, 'score': 15}`
  /// for games, or `{'strokes': [...]}` for drawing.
  final Map<String, dynamic> progressData;

  const ActivitySaveState({
    required this.activityId,
    required this.savedAt,
    required this.elapsedSeconds,
    this.difficultyLevel = 1,
    this.speedMultiplier = 1.0,
    this.progressData = const {},
  });

  // ── Serialisation ─────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'activityId': activityId,
        'savedAt': savedAt.toIso8601String(),
        'elapsedSeconds': elapsedSeconds,
        'difficultyLevel': difficultyLevel,
        'speedMultiplier': speedMultiplier,
        'progressData': progressData,
      };

  /// Returns `null` if the JSON is malformed or missing required keys
  /// (alt-flow: corrupted save data).
  static ActivitySaveState? fromJson(Map<String, dynamic> json) {
    try {
      return ActivitySaveState(
        activityId: json['activityId'] as String,
        savedAt: DateTime.parse(json['savedAt'] as String),
        elapsedSeconds: json['elapsedSeconds'] as int,
        difficultyLevel: (json['difficultyLevel'] as int?) ?? 1,
        speedMultiplier: (json['speedMultiplier'] as num?)?.toDouble() ?? 1.0,
        progressData:
            (json['progressData'] as Map<String, dynamic>?) ?? const {},
      );
    } catch (_) {
      return null; // corrupted → caller will auto-delete
    }
  }

  /// Convenience: encode to a JSON string ready for SharedPreferences.
  String encode() => jsonEncode(toJson());

  /// Convenience: decode from a JSON string. Returns `null` on error.
  static ActivitySaveState? decode(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => 'ActivitySaveState(id=$activityId, '
      'elapsed=${elapsedSeconds}s, diff=$difficultyLevel)';
}
