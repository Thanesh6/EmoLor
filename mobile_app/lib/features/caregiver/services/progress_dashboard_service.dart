import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/star_service.dart';
import '../../child/models/completion_record.dart';
import '../../child/services/completion_service.dart';

// ── Data models ──────────────────────────────────────────────────────

/// Aggregated progress snapshot for the caregiver dashboard.
class ProgressData {
  final List<DailyMood> weeklyMoods;
  final ActivityStats activityStats;
  final Map<String, int> starBreakdown;
  final int totalStars;
  final List<Badge> earnedBadges;
  final List<CompletionRecord> recentCompletions;

  const ProgressData({
    required this.weeklyMoods,
    required this.activityStats,
    required this.starBreakdown,
    required this.totalStars,
    required this.earnedBadges,
    required this.recentCompletions,
  });

  bool get isEmpty =>
      weeklyMoods.every((d) => d.entries.isEmpty) &&
      activityStats.totalCompleted == 0 &&
      totalStars == 0;
}

/// A single day's mood entries for the bar chart.
class DailyMood {
  final DateTime date;
  final String dayLabel; // M, T, W …
  final List<MoodSnapshot> entries;

  const DailyMood({
    required this.date,
    required this.dayLabel,
    required this.entries,
  });

  /// Dominant mood for the day (most frequent emotion).
  String? get dominantEmotion {
    if (entries.isEmpty) return null;
    final counts = <String, int>{};
    for (final e in entries) {
      counts[e.emotionId] = (counts[e.emotionId] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Average intensity (entry count as proxy, capped at 5).
  double get intensity =>
      entries.isEmpty ? 0 : (entries.length).clamp(0, 5).toDouble();
}

class MoodSnapshot {
  final String emotionId;
  final DateTime timestamp;

  const MoodSnapshot({required this.emotionId, required this.timestamp});
}

class ActivityStats {
  final int totalCompleted;
  final int totalTimeSeconds;
  final int totalStarsEarned;
  final double averageScore;
  final Map<String, int> completionsByActivity;

  const ActivityStats({
    required this.totalCompleted,
    required this.totalTimeSeconds,
    required this.totalStarsEarned,
    required this.averageScore,
    required this.completionsByActivity,
  });
}

/// A badge the child has earned based on milestone criteria.
class Badge {
  final String id;
  final String title;
  final String emoji;
  final String description;
  final Color color;

  const Badge({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    required this.color,
  });
}

// ── Service ──────────────────────────────────────────────────────────

class ProgressDashboardService {
  static const String _moodKey = 'user_mood_entries';

  /// Load all progress data in one call.
  Future<ProgressData> loadProgress() async {
    final results = await Future.wait([
      _loadWeeklyMoods(),
      _loadActivityStats(),
      StarService.getBreakdown(),
      StarService.getTotalStars(),
      CompletionService.history(),
    ]);

    final weeklyMoods = results[0] as List<DailyMood>;
    final activityStats = results[1] as ActivityStats;
    final starBreakdown = results[2] as Map<String, int>;
    final totalStars = results[3] as int;
    final history = results[4] as List<CompletionRecord>;
    final badges = _computeBadges(
      totalStars: totalStars,
      totalCompleted: activityStats.totalCompleted,
      weeklyMoods: weeklyMoods,
      history: history,
    );

    return ProgressData(
      weeklyMoods: weeklyMoods,
      activityStats: activityStats,
      starBreakdown: starBreakdown,
      totalStars: totalStars,
      earnedBadges: badges,
      recentCompletions: history.take(5).toList(),
    );
  }

  // ── Mood trends ────────────────────────────────────────────────────

  Future<List<DailyMood>> _loadWeeklyMoods() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_moodKey);

    List<MoodSnapshot> allMoods = [];
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        allMoods = decoded.map((e) {
          return MoodSnapshot(
            emotionId: e['emotionId'] as String,
            timestamp: DateTime.parse(e['timestamp'] as String),
          );
        }).toList();
      } catch (_) {}
    }

    final now = DateTime.now();
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final List<DailyMood> week = [];

    for (int i = 6; i >= 0; i--) {
      final day =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dayEntries = allMoods.where((m) {
        final d = m.timestamp;
        return d.year == day.year && d.month == day.month && d.day == day.day;
      }).toList();

      week.add(DailyMood(
        date: day,
        dayLabel: dayLabels[day.weekday - 1], // weekday: 1=Mon
        entries: dayEntries,
      ));
    }

    return week;
  }

  // ── Activity stats ─────────────────────────────────────────────────

  Future<ActivityStats> _loadActivityStats() async {
    final history = await CompletionService.history();

    if (history.isEmpty) {
      return const ActivityStats(
        totalCompleted: 0,
        totalTimeSeconds: 0,
        totalStarsEarned: 0,
        averageScore: 0,
        completionsByActivity: {},
      );
    }

    int totalTime = 0;
    int totalStarsEarned = 0;
    double scoreSum = 0;
    int scoredCount = 0;
    final byActivity = <String, int>{};

    for (final r in history) {
      totalTime += r.timeSpentSeconds;
      totalStarsEarned += r.starsEarned;
      if (r.scoreMax > 0) {
        scoreSum += (r.scoreValue / r.scoreMax) * 100;
        scoredCount++;
      }
      byActivity[r.activityName] = (byActivity[r.activityName] ?? 0) + 1;
    }

    return ActivityStats(
      totalCompleted: history.length,
      totalTimeSeconds: totalTime,
      totalStarsEarned: totalStarsEarned,
      averageScore: scoredCount > 0 ? scoreSum / scoredCount : 0,
      completionsByActivity: byActivity,
    );
  }

  // ── Badges (milestone-based) ───────────────────────────────────────

  List<Badge> _computeBadges({
    required int totalStars,
    required int totalCompleted,
    required List<DailyMood> weeklyMoods,
    required List<CompletionRecord> history,
  }) {
    final badges = <Badge>[];

    // ⭐ Star milestones
    if (totalStars >= 1) {
      badges.add(const Badge(
        id: 'first_star',
        title: 'First Star',
        emoji: '⭐',
        description: 'Earned your very first star!',
        color: Color(0xFFFFB300),
      ));
    }
    if (totalStars >= 10) {
      badges.add(const Badge(
        id: 'star_collector',
        title: 'Star Collector',
        emoji: '🌟',
        description: 'Collected 10 stars!',
        color: Color(0xFFFF8F00),
      ));
    }
    if (totalStars >= 50) {
      badges.add(const Badge(
        id: 'star_master',
        title: 'Star Master',
        emoji: '💫',
        description: 'An incredible 50 stars!',
        color: Color(0xFFF57C00),
      ));
    }
    if (totalStars >= 100) {
      badges.add(const Badge(
        id: 'superstar',
        title: 'Superstar',
        emoji: '🏆',
        description: 'Over 100 stars — amazing!',
        color: Color(0xFFE65100),
      ));
    }

    // 🎮 Activity milestones
    if (totalCompleted >= 1) {
      badges.add(const Badge(
        id: 'first_activity',
        title: 'First Step',
        emoji: '👣',
        description: 'Completed your first activity!',
        color: Color(0xFF42A5F5),
      ));
    }
    if (totalCompleted >= 5) {
      badges.add(const Badge(
        id: 'explorer',
        title: 'Explorer',
        emoji: '🧭',
        description: 'Completed 5 activities!',
        color: Color(0xFF1E88E5),
      ));
    }
    if (totalCompleted >= 20) {
      badges.add(const Badge(
        id: 'adventurer',
        title: 'Adventurer',
        emoji: '🗺️',
        description: 'Completed 20 activities!',
        color: Color(0xFF1565C0),
      ));
    }

    // 😊 Mood milestones
    final totalMoodEntries = weeklyMoods.fold<int>(
      0,
      (sum, d) => sum + d.entries.length,
    );
    if (totalMoodEntries >= 1) {
      badges.add(const Badge(
        id: 'mood_starter',
        title: 'Mood Tracker',
        emoji: '🎭',
        description: 'Logged your first mood!',
        color: Color(0xFF66BB6A),
      ));
    }

    // 🔥 Streak — days with at least one mood entry this week
    final activeDays = weeklyMoods.where((d) => d.entries.isNotEmpty).length;
    if (activeDays >= 3) {
      badges.add(const Badge(
        id: 'streak_3',
        title: '3-Day Streak',
        emoji: '🔥',
        description: 'Logged moods 3 days this week!',
        color: Color(0xFFEF5350),
      ));
    }
    if (activeDays >= 7) {
      badges.add(const Badge(
        id: 'streak_7',
        title: 'Full Week',
        emoji: '🌈',
        description: 'A full week of mood tracking!',
        color: Color(0xFFAB47BC),
      ));
    }

    return badges;
  }
}
