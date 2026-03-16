import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';

/// UCD043 – View Activity Engagement Trends
///
/// Computes analytics from the `activity_progress` table for a specific
/// child over a selected date range:
/// • Top activities by frequency
/// • Average daily session duration
/// • Completion rate (started vs finished)
/// • Daily usage breakdown for line/bar charts
class EngagementAnalyticsService {
  final SupabaseClient _client = SupabaseService.client;

  /// Fetches raw activity-progress rows for [childId] within [start]..[end].
  ///
  /// Optional [activityTypes] filters by activity type (game, exercise, etc.).
  /// Optional [statusFilter] filters by completion status.
  Future<EngagementData> getEngagement({
    required String childId,
    required DateTime start,
    required DateTime end,
    Set<String>? activityTypes,
    String? statusFilter,
  }) async {
    try {
      final rows = await _client
          .from('activity_progress')
          .select('*, activities(title, activity_type)')
          .eq('child_profile_id', childId)
          .gte('updated_at', start.toUtc().toIso8601String())
          .lte('updated_at', end.toUtc().toIso8601String())
          .order('updated_at', ascending: true) as List;

      if (rows.isEmpty) return EngagementData.empty();

      return _compute(rows, start, end,
          activityTypes: activityTypes, statusFilter: statusFilter);
    } catch (e) {
      debugPrint('EngagementAnalyticsService.getEngagement error: $e');
      return EngagementData.empty();
    }
  }

  // ── Computation ───────────────────────────────────────────────────────

  EngagementData _compute(
    List<dynamic> rows,
    DateTime start,
    DateTime end, {
    Set<String>? activityTypes,
    String? statusFilter,
  }) {
    // ── Accumulators ──
    final activityFreq = <String, int>{};
    final activityType = <String, String>{};
    final dailySecs = <String, int>{}; // 'yyyy-MM-dd' → total seconds
    int totalStarted = 0;
    int totalCompleted = 0;
    int totalTimeSecs = 0;
    final dataPoints = <ActivityDataPoint>[];

    for (final r in rows) {
      final act = r['activities'] as Map<String, dynamic>?;
      final title = (act?['title'] as String?) ?? 'Unknown';
      final type = (act?['activity_type'] as String?) ?? '';
      final status = (r['status'] as String?) ?? 'started';

      // UCD046 – Apply filters
      if (activityTypes != null &&
          activityTypes.isNotEmpty &&
          !activityTypes.contains(type)) {
        continue;
      }
      if (statusFilter != null && status != statusFilter) continue;
      final timeSecs = (r['time_spent_seconds'] as int?) ?? 0;
      final updatedAt = DateTime.parse(r['updated_at'] as String);
      final dayKey =
          '${updatedAt.year}-${updatedAt.month.toString().padLeft(2, '0')}-${updatedAt.day.toString().padLeft(2, '0')}';

      activityFreq[title] = (activityFreq[title] ?? 0) + 1;
      activityType[title] = type;
      dailySecs[dayKey] = (dailySecs[dayKey] ?? 0) + timeSecs;
      totalTimeSecs += timeSecs;
      totalStarted++;
      if (status == 'completed') totalCompleted++;

      dataPoints.add(ActivityDataPoint(
        activityTitle: title,
        activityType: type,
        date: updatedAt,
        durationSecs: timeSecs,
        status: status,
        score: r['score'] as int?,
        completionPct: (r['completion_percentage'] as int?) ?? 0,
      ));
    }

    // ── Top activities (sorted by frequency desc, take top 8) ──
    final sortedActs = activityFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topActivities = sortedActs
        .take(8)
        .map((e) => TopActivity(
              title: e.key,
              count: e.value,
              activityType: activityType[e.key] ?? '',
            ))
        .toList();

    // ── Daily usage for line chart ──
    final dayCount = end.difference(start).inDays + 1;
    final dailyUsage = <DailyUsage>[];
    for (var i = 0; i < dayCount; i++) {
      final d = start.add(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      dailyUsage.add(DailyUsage(
        date: d,
        totalSecs: dailySecs[key] ?? 0,
      ));
    }

    // ── Averages ──
    final daysWithData = dailySecs.length;
    final avgDailyMins =
        daysWithData > 0 ? (totalTimeSecs / daysWithData / 60).round() : 0;
    final completionRate =
        totalStarted > 0 ? (totalCompleted / totalStarted * 100).round() : 0;

    return EngagementData(
      topActivities: topActivities,
      dailyUsage: dailyUsage,
      dataPoints: dataPoints,
      totalSessions: totalStarted,
      totalCompleted: totalCompleted,
      completionRate: completionRate,
      avgDailyMinutes: avgDailyMins,
      totalMinutes: (totalTimeSecs / 60).round(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Data classes ─────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

@immutable
class EngagementData {
  final List<TopActivity> topActivities;
  final List<DailyUsage> dailyUsage;
  final List<ActivityDataPoint> dataPoints;
  final int totalSessions;
  final int totalCompleted;
  final int completionRate; // 0–100
  final int avgDailyMinutes;
  final int totalMinutes;

  const EngagementData({
    required this.topActivities,
    required this.dailyUsage,
    required this.dataPoints,
    required this.totalSessions,
    required this.totalCompleted,
    required this.completionRate,
    required this.avgDailyMinutes,
    required this.totalMinutes,
  });

  bool get isEmpty => totalSessions == 0;

  factory EngagementData.empty() => const EngagementData(
        topActivities: [],
        dailyUsage: [],
        dataPoints: [],
        totalSessions: 0,
        totalCompleted: 0,
        completionRate: 0,
        avgDailyMinutes: 0,
        totalMinutes: 0,
      );
}

@immutable
class TopActivity {
  final String title;
  final int count;
  final String activityType;

  const TopActivity({
    required this.title,
    required this.count,
    required this.activityType,
  });
}

@immutable
class DailyUsage {
  final DateTime date;
  final int totalSecs;

  const DailyUsage({required this.date, required this.totalSecs});

  double get totalMinutes => totalSecs / 60;
}

@immutable
class ActivityDataPoint {
  final String activityTitle;
  final String activityType;
  final DateTime date;
  final int durationSecs;
  final String status;
  final int? score;
  final int completionPct;

  const ActivityDataPoint({
    required this.activityTitle,
    required this.activityType,
    required this.date,
    required this.durationSecs,
    required this.status,
    this.score,
    required this.completionPct,
  });

  String get formattedDuration {
    final mins = durationSecs ~/ 60;
    return mins > 0 ? '$mins min' : '${durationSecs}s';
  }
}
