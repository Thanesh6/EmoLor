import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../child/models/completion_record.dart';

// ── Data models ──────────────────────────────────────────────────────

/// Category of a performance goal.
enum GoalCategory {
  timeSpent,
  activityCompletion,
  moodLogging,
  starCollection,
}

/// Time span for the goal.
enum GoalDuration {
  today,
  thisWeek,
  thisMonth,
}

/// Current status of the goal.
enum GoalStatus {
  active,
  completed,
  expired,
}

/// A single performance goal set by a caregiver.
class PerformanceGoal {
  final String id;
  final GoalCategory category;
  final int target;
  final GoalDuration duration;
  final String? linkedReward;
  final GoalStatus status;
  final int currentProgress;
  final DateTime createdAt;

  const PerformanceGoal({
    required this.id,
    required this.category,
    required this.target,
    required this.duration,
    this.linkedReward,
    this.status = GoalStatus.active,
    this.currentProgress = 0,
    required this.createdAt,
  });

  double get progressFraction =>
      target > 0 ? (currentProgress / target).clamp(0.0, 1.0) : 0.0;

  bool get isComplete => currentProgress >= target;

  PerformanceGoal copyWith({
    GoalStatus? status,
    int? currentProgress,
  }) {
    return PerformanceGoal(
      id: id,
      category: category,
      target: target,
      duration: duration,
      linkedReward: linkedReward,
      status: status ?? this.status,
      currentProgress: currentProgress ?? this.currentProgress,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.index,
        'target': target,
        'duration': duration.index,
        'linkedReward': linkedReward,
        'status': status.index,
        'currentProgress': currentProgress,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PerformanceGoal.fromJson(Map<String, dynamic> j) => PerformanceGoal(
        id: j['id'] as String,
        category: GoalCategory.values[j['category'] as int],
        target: j['target'] as int? ?? 1,
        duration: GoalDuration.values[j['duration'] as int],
        linkedReward: j['linkedReward'] as String?,
        status: GoalStatus.values[j['status'] as int? ?? 0],
        currentProgress: j['currentProgress'] as int? ?? 0,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

// ── Helpers ──────────────────────────────────────────────────────────

extension GoalCategoryLabel on GoalCategory {
  String get label {
    switch (this) {
      case GoalCategory.timeSpent:
        return 'Time Spent';
      case GoalCategory.activityCompletion:
        return 'Activity Completion';
      case GoalCategory.moodLogging:
        return 'Mood Logging';
      case GoalCategory.starCollection:
        return 'Star Collection';
    }
  }

  String get emoji {
    switch (this) {
      case GoalCategory.timeSpent:
        return '⏱️';
      case GoalCategory.activityCompletion:
        return '🎮';
      case GoalCategory.moodLogging:
        return '🎭';
      case GoalCategory.starCollection:
        return '⭐';
    }
  }

  String unitLabel(int target) {
    switch (this) {
      case GoalCategory.timeSpent:
        return '$target min';
      case GoalCategory.activityCompletion:
        return '$target activities';
      case GoalCategory.moodLogging:
        return '$target entries';
      case GoalCategory.starCollection:
        return '$target stars';
    }
  }
}

extension GoalDurationLabel on GoalDuration {
  String get label {
    switch (this) {
      case GoalDuration.today:
        return 'Today';
      case GoalDuration.thisWeek:
        return 'This Week';
      case GoalDuration.thisMonth:
        return 'This Month';
    }
  }
}

extension GoalStatusLabel on GoalStatus {
  String get label {
    switch (this) {
      case GoalStatus.active:
        return 'Active';
      case GoalStatus.completed:
        return 'Completed';
      case GoalStatus.expired:
        return 'Expired';
    }
  }
}

// ── Available reward options for linking ─────────────────────────────

/// A linkable in-app reward with visual metadata.
class RewardOption {
  final String id;
  final String title;
  final String emoji;
  final String description;
  final int colorValue;

  const RewardOption({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    required this.colorValue,
  });
}

/// Master catalogue of rewards a caregiver can assign to a goal.
const List<RewardOption> availableRewardOptions = [
  RewardOption(
    id: 'space_badge',
    title: 'Space Badge',
    emoji: '🚀',
    description: 'Unlock the Space Explorer badge',
    colorValue: 0xFF1565C0,
  ),
  RewardOption(
    id: 'rainbow_badge',
    title: 'Rainbow Badge',
    emoji: '🌈',
    description: 'Unlock the Rainbow Champion badge',
    colorValue: 0xFFAB47BC,
  ),
  RewardOption(
    id: 'ocean_badge',
    title: 'Ocean Badge',
    emoji: '🐬',
    description: 'Unlock the Ocean Adventurer badge',
    colorValue: 0xFF0097A7,
  ),
  RewardOption(
    id: 'forest_badge',
    title: 'Forest Badge',
    emoji: '🌳',
    description: 'Unlock the Forest Guardian badge',
    colorValue: 0xFF2E7D32,
  ),
  RewardOption(
    id: 'music_badge',
    title: 'Music Badge',
    emoji: '🎵',
    description: 'Unlock the Music Maestro badge',
    colorValue: 0xFFE65100,
  ),
  RewardOption(
    id: 'robot_badge',
    title: 'Robot Badge',
    emoji: '🤖',
    description: 'Unlock the Robot Builder badge',
    colorValue: 0xFF455A64,
  ),
  RewardOption(
    id: 'space_theme',
    title: 'Space Theme',
    emoji: '🌌',
    description: 'Unlock the Outer Space app theme',
    colorValue: 0xFF283593,
  ),
  RewardOption(
    id: 'ocean_theme',
    title: 'Ocean Theme',
    emoji: '🌊',
    description: 'Unlock the Deep Ocean app theme',
    colorValue: 0xFF00838F,
  ),
  RewardOption(
    id: 'story_time',
    title: 'Extra Story Time',
    emoji: '📖',
    description: 'Unlock a bonus story session',
    colorValue: 0xFF6A1B9A,
  ),
  RewardOption(
    id: 'sticker_pack',
    title: 'Sticker Pack',
    emoji: '🎨',
    description: 'Unlock a special sticker pack',
    colorValue: 0xFFC62828,
  ),
  RewardOption(
    id: 'custom_avatar',
    title: 'Custom Avatar',
    emoji: '🧑‍🎨',
    description: 'Unlock custom avatar accessories',
    colorValue: 0xFFFF8F00,
  ),
  RewardOption(
    id: 'dance_party',
    title: 'Dance Party',
    emoji: '💃',
    description: 'Unlock the dance party celebration',
    colorValue: 0xFFD81B60,
  ),
];

/// Legacy string list — kept for backward compatibility.
const List<String> availableRewards = [
  'Unlock Space Badge',
  'Unlock Rainbow Badge',
  'Unlock Ocean Badge',
  'Unlock Forest Badge',
  'Unlock Music Badge',
  'Extra Story Time',
  'Special Sticker Pack',
  'Custom Avatar',
];

// ── Service ──────────────────────────────────────────────────────────

/// Persists performance goals to SharedPreferences.
///
/// Follows the same offline-first pattern as CompletionService / StarService.
class GoalService {
  static const _profileIdKey = 'selected_child_profile_id';
  static const _uuid = Uuid();

  /// Per-child storage key. Falls back to a `'no_profile'` bucket if no
  /// child profile is selected — never to a caregiver-wide key, which
  /// would let siblings share goals.
  static Future<String> _storageKeyAsync() async {
    final prefs = await SharedPreferences.getInstance();
    final profileId = prefs.getString(_profileIdKey) ?? 'no_profile';
    return 'performance_goals_$profileId';
  }

  /// Create and persist a new goal. Returns the created goal.
  ///
  /// Throws [ArgumentError] if the target is <= 0.
  static Future<PerformanceGoal> createGoal({
    required GoalCategory category,
    required int target,
    required GoalDuration duration,
    String? linkedReward,
  }) async {
    if (target <= 0) {
      throw ArgumentError('Please set a valid target number.');
    }

    final goal = PerformanceGoal(
      id: _uuid.v4(),
      category: category,
      target: target,
      duration: duration,
      linkedReward: linkedReward,
      status: GoalStatus.active,
      currentProgress: 0,
      createdAt: DateTime.now(),
    );

    final all = await _loadAll();
    all.add(goal);
    await _saveAll(all);
    return goal;
  }

  /// Return all goals, newest first.
  static Future<List<PerformanceGoal>> getAllGoals() async {
    final all = await _loadAll();
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  /// Return only active goals.
  static Future<List<PerformanceGoal>> getActiveGoals() async {
    return (await getAllGoals())
        .where((g) => g.status == GoalStatus.active)
        .toList();
  }

  /// Update progress for a goal.
  static Future<void> updateProgress(String goalId, int newProgress) async {
    final all = await _loadAll();
    final idx = all.indexWhere((g) => g.id == goalId);
    if (idx == -1) return;

    var goal = all[idx].copyWith(currentProgress: newProgress);
    if (goal.isComplete && goal.status == GoalStatus.active) {
      goal = goal.copyWith(status: GoalStatus.completed);
    }
    all[idx] = goal;
    await _saveAll(all);
  }

  /// Mark a goal as completed.
  static Future<void> completeGoal(String goalId) async {
    final all = await _loadAll();
    final idx = all.indexWhere((g) => g.id == goalId);
    if (idx == -1) return;
    all[idx] = all[idx].copyWith(status: GoalStatus.completed);
    await _saveAll(all);
  }

  /// Delete a goal by id.
  static Future<void> deleteGoal(String goalId) async {
    final all = await _loadAll();
    all.removeWhere((g) => g.id == goalId);
    await _saveAll(all);
  }

  /// Clear all goals for the current child profile.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _storageKeyAsync();
    await prefs.remove(key);
  }

  // ── Live progress calculation ────────────────────────────────────
  //
  // The stored `currentProgress` field is never written to in this
  // codebase — the games and emotion screens log their data into
  // StarService / CompletionService / EmotionJournalService directly.
  // Computing the goal's "current" value live from those sources is
  // what actually drives the progress bars in the caregiver and
  // analytics dashboards.
  //
  // Per-goal window:
  //   today      → since 00:00 today
  //   thisWeek   → since Monday 00:00
  //   thisMonth  → since the 1st 00:00
  //
  // Goals created mid-window count from their `createdAt` instead, so
  // the bar never includes activity that happened before the goal was
  // set.

  /// Pure helper — given the raw data sources, returns the live
  /// `current` integer for [goal]. Callers fetch the data themselves
  /// (this keeps the helper deterministic and easy to test).
  static int liveCurrentForGoal(
    PerformanceGoal goal, {
    required int totalStars,
    required List<CompletionRecord> completions,
    required List<Map<String, dynamic>> journal,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();

    DateTime windowStart() {
      DateTime period;
      switch (goal.duration) {
        case GoalDuration.today:
          period = DateTime(n.year, n.month, n.day);
          break;
        case GoalDuration.thisWeek:
          final ws = n.subtract(Duration(days: n.weekday - 1));
          period = DateTime(ws.year, ws.month, ws.day);
          break;
        case GoalDuration.thisMonth:
          period = DateTime(n.year, n.month, 1);
          break;
      }
      return goal.createdAt.isAfter(period) ? goal.createdAt : period;
    }

    final start = windowStart();

    switch (goal.category) {
      case GoalCategory.starCollection:
        // Stars are cumulative per profile. We don't have per-day star
        // history, so the best signal is the running total — clamped
        // to the target so the bar reads cleanly when over-target.
        return totalStars;

      case GoalCategory.activityCompletion:
        return completions
            .where((c) => c.completedAt.isAfter(start))
            .length;

      case GoalCategory.timeSpent:
        // Target is in minutes; timeSpentSeconds adds up across all
        // in-window completions and rounds to whole minutes.
        final secs = completions
            .where((c) => c.completedAt.isAfter(start))
            .fold<int>(0, (sum, c) => sum + c.timeSpentSeconds);
        return (secs / 60).round();

      case GoalCategory.moodLogging:
        return journal.where((e) {
          final ts = DateTime.tryParse(e['timestamp'] as String? ?? '');
          return ts != null && ts.isAfter(start);
        }).length;
    }
  }

  /// Convenience wrapper — compute the [0.0, 1.0] progress fraction for
  /// the given goal using the same data sources as
  /// [liveCurrentForGoal]. Always clamped so progress bars never
  /// overflow.
  static double liveProgressFraction(
    PerformanceGoal goal, {
    required int totalStars,
    required List<CompletionRecord> completions,
    required List<Map<String, dynamic>> journal,
    DateTime? now,
  }) {
    if (goal.target <= 0) return 0.0;
    final cur = liveCurrentForGoal(
      goal,
      totalStars: totalStars,
      completions: completions,
      journal: journal,
      now: now,
    );
    return (cur / goal.target).clamp(0.0, 1.0);
  }

  // ── Private helpers ──────────────────────────────────────────────

  static Future<List<PerformanceGoal>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _storageKeyAsync();
    final raw = prefs.getString(key);
    if (raw == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded
          .map((e) => PerformanceGoal.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveAll(List<PerformanceGoal> goals) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _storageKeyAsync();
    final encoded = jsonEncode(goals.map((g) => g.toJson()).toList());
    await prefs.setString(key, encoded);
  }
}
