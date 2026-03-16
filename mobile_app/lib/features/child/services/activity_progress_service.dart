import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity_save_state.dart';

/// UCD014 – Local persistence service for in-progress activity state.
///
/// Uses SharedPreferences with key pattern `activity_progress_{id}`.
/// All methods are safe: corrupted data is silently deleted
/// (alt-flow 2: corrupted save data).
class ActivityProgressService {
  /// SharedPreferences key prefix.
  static const _prefix = 'activity_progress_';

  // ── Public API ────────────────────────────────────────────────────────

  /// Save (or overwrite) progress for the given activity.
  Future<void> saveProgress(ActivitySaveState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix${state.activityId}', state.encode());
  }

  /// Load saved progress for [activityId].
  /// Returns `null` when no save exists **or** when the save is corrupted
  /// (in which case the bad entry is auto-deleted).
  Future<ActivitySaveState?> loadProgress(String activityId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$activityId');
    if (raw == null) return null;

    final state = ActivitySaveState.decode(raw);
    if (state == null) {
      // Alt-flow 2: corrupted save data → silently remove it.
      await prefs.remove('$_prefix$activityId');
    }
    return state;
  }

  /// Delete saved progress for [activityId].
  Future<void> deleteProgress(String activityId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$activityId');
  }

  /// Quick check whether saved progress exists and is valid.
  Future<bool> hasProgress(String activityId) async {
    final state = await loadProgress(activityId);
    return state != null;
  }

  /// Return all activity ids that currently have a valid save.
  Future<Set<String>> allInProgressIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = <String>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_prefix)) {
        final activityId = key.substring(_prefix.length);
        final raw = prefs.getString(key);
        if (raw != null && ActivitySaveState.decode(raw) != null) {
          ids.add(activityId);
        }
      }
    }
    return ids;
  }
}
