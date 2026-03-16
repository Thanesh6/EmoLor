import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';

/// UCD044 – View Performance Statistics
///
/// Computes per-skill-category metrics from `activity_progress` joined
/// with `activities`:
///  • Accuracy rate
///  • Average response time
///  • Adaptive difficulty level
///  • Score distribution
///  • Progress over time
class PerformanceStatsService {
  final SupabaseClient _client = SupabaseService.client;

  /// All recognised skill categories (matches DB CHECK constraint).
  static const List<String> skillCategories = [
    'Emotion Recognition',
    'Social Cues',
    'Self-Regulation',
    'Creative Expression',
    'Cognitive Skills',
    'General',
  ];

  /// Fetches performance data for [childId] within [start]..[end],
  /// optionally filtered by [category].
  ///
  /// Optional [activityTypes] filters by activity type.
  /// Optional [skillCategories] filters by skill category.
  /// Optional [statusFilter] filters by completion status.
  Future<PerformanceData> getPerformance({
    required String childId,
    required DateTime start,
    required DateTime end,
    String? category,
    Set<String>? activityTypes,
    Set<String>? skillCategories,
    String? statusFilter,
  }) async {
    try {
      var query = _client
          .from('activity_progress')
          .select(
              '*, activities(title, activity_type, difficulty, skill_category)')
          .eq('child_profile_id', childId)
          .gte('updated_at', start.toUtc().toIso8601String())
          .lte('updated_at', end.toUtc().toIso8601String());

      final rows = await query.order('updated_at', ascending: true) as List;
      if (rows.isEmpty) return PerformanceData.empty();

      return _compute(rows, category,
          activityTypes: activityTypes,
          skillCategories: skillCategories,
          statusFilter: statusFilter);
    } catch (e) {
      debugPrint('PerformanceStatsService.getPerformance error: $e');
      return PerformanceData.empty();
    }
  }

  // ── Computation ───────────────────────────────────────────────────────

  PerformanceData _compute(
    List<dynamic> rows,
    String? filterCategory, {
    Set<String>? activityTypes,
    Set<String>? skillCategories,
    String? statusFilter,
  }) {
    // Group by skill_category
    final catMap = <String, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      final act = r['activities'] as Map<String, dynamic>?;
      final type = (act?['activity_type'] as String?) ?? '';
      final status = (r['status'] as String?) ?? 'started';

      // UCD046 – Apply filters
      if (activityTypes != null &&
          activityTypes.isNotEmpty &&
          !activityTypes.contains(type)) {
        continue;
      }
      if (statusFilter != null && status != statusFilter) continue;
      final cat = (act?['skill_category'] as String?) ?? 'General';
      if (skillCategories != null &&
          skillCategories.isNotEmpty &&
          !skillCategories.contains(cat)) {
        continue;
      }
      catMap.putIfAbsent(cat, () => []).add(r as Map<String, dynamic>);
    }

    // Build per-category stats
    final categoryStats = <String, CategoryPerformance>{};
    for (final entry in catMap.entries) {
      categoryStats[entry.key] = _categoryStats(entry.key, entry.value);
    }

    // If a filter is applied, select only that category
    final activeCat =
        filterCategory != null && catMap.containsKey(filterCategory)
            ? filterCategory
            : null;

    // Radar data: one axis per category (accuracy 0–100)
    final radarAxes = <RadarAxis>[];
    for (final cat in PerformanceStatsService.skillCategories) {
      final cs = categoryStats[cat];
      radarAxes.add(RadarAxis(
        category: cat,
        accuracy: cs?.accuracyRate ?? 0,
        sessions: cs?.totalSessions ?? 0,
      ));
    }

    // Overall aggregates
    int totalSessions = 0;
    int totalCompleted = 0;
    double sumAccuracy = 0;
    double sumResponseMs = 0;
    int metricsCount = 0;
    int maxLevel = 1;

    for (final cs in categoryStats.values) {
      totalSessions += cs.totalSessions;
      totalCompleted += cs.completedSessions;
      if (cs.totalSessions > 0) {
        sumAccuracy += cs.accuracyRate;
        sumResponseMs += cs.avgResponseTimeMs;
        metricsCount++;
      }
      if (cs.currentLevel > maxLevel) maxLevel = cs.currentLevel;
    }

    final overallAccuracy =
        metricsCount > 0 ? (sumAccuracy / metricsCount).round() : 0;
    final overallResponseMs =
        metricsCount > 0 ? (sumResponseMs / metricsCount).round() : 0;

    return PerformanceData(
      categoryStats: categoryStats,
      radarAxes: radarAxes,
      activeCategory: activeCat,
      totalSessions: totalSessions,
      totalCompleted: totalCompleted,
      overallAccuracy: overallAccuracy,
      overallResponseTimeMs: overallResponseMs,
      currentLevel: maxLevel,
      hasSufficientData: totalCompleted >= 5,
    );
  }

  CategoryPerformance _categoryStats(
      String category, List<Map<String, dynamic>> rows) {
    int total = rows.length;
    int completed = 0;
    int sumScore = 0;
    int sumAccuracy = 0;
    int sumResponseMs = 0;
    int sumLevel = 0;
    int scored = 0;
    int withAccuracy = 0;
    int withResponse = 0;
    int maxLevel = 1;
    final timeline = <PerformancePoint>[];

    for (final r in rows) {
      final act = r['activities'] as Map<String, dynamic>?;
      final status = (r['status'] as String?) ?? 'started';
      final score = r['score'] as int?;
      final accuracy = r['accuracy_pct'] as int? ?? 0;
      final responseMs = r['response_time_ms'] as int? ?? 0;
      final level = r['difficulty_level'] as int? ?? 1;
      final updatedAt = DateTime.parse(r['updated_at'] as String);
      final title = (act?['title'] as String?) ?? 'Activity';
      final difficulty = (act?['difficulty'] as String?) ?? 'easy';

      if (status == 'completed') completed++;
      if (score != null) {
        sumScore += score;
        scored++;
      }
      if (accuracy > 0) {
        sumAccuracy += accuracy;
        withAccuracy++;
      }
      if (responseMs > 0) {
        sumResponseMs += responseMs;
        withResponse++;
      }
      sumLevel += level;
      if (level > maxLevel) maxLevel = level;

      timeline.add(PerformancePoint(
        date: updatedAt,
        activityTitle: title,
        score: score,
        accuracyPct: accuracy,
        responseTimeMs: responseMs,
        difficultyLevel: level,
        difficulty: difficulty,
        status: status,
      ));
    }

    // Derive accuracy from score if accuracy_pct not populated
    final effectiveAccuracy = withAccuracy > 0
        ? (sumAccuracy / withAccuracy).round()
        : scored > 0
            ? (sumScore / scored).clamp(0, 100).round()
            : 0;

    return CategoryPerformance(
      category: category,
      totalSessions: total,
      completedSessions: completed,
      accuracyRate: effectiveAccuracy,
      avgResponseTimeMs:
          withResponse > 0 ? (sumResponseMs / withResponse).round() : 0,
      avgScore: scored > 0 ? (sumScore / scored).round() : 0,
      currentLevel: maxLevel,
      avgLevel: total > 0 ? (sumLevel / total).round() : 1,
      timeline: timeline,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Data classes ─────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

@immutable
class PerformanceData {
  final Map<String, CategoryPerformance> categoryStats;
  final List<RadarAxis> radarAxes;
  final String? activeCategory;
  final int totalSessions;
  final int totalCompleted;
  final int overallAccuracy; // 0–100
  final int overallResponseTimeMs;
  final int currentLevel;
  final bool hasSufficientData;

  const PerformanceData({
    required this.categoryStats,
    required this.radarAxes,
    this.activeCategory,
    required this.totalSessions,
    required this.totalCompleted,
    required this.overallAccuracy,
    required this.overallResponseTimeMs,
    required this.currentLevel,
    required this.hasSufficientData,
  });

  bool get isEmpty => totalSessions == 0;

  String get levelLabel {
    switch (currentLevel) {
      case 1:
        return 'Level 1 – Basic';
      case 2:
        return 'Level 2 – Intermediate';
      case 3:
        return 'Level 3 – Complex Emotions';
      case 4:
        return 'Level 4 – Advanced';
      case 5:
        return 'Level 5 – Expert';
      default:
        return 'Level $currentLevel';
    }
  }

  factory PerformanceData.empty() => const PerformanceData(
        categoryStats: {},
        radarAxes: [],
        totalSessions: 0,
        totalCompleted: 0,
        overallAccuracy: 0,
        overallResponseTimeMs: 0,
        currentLevel: 1,
        hasSufficientData: false,
      );
}

@immutable
class CategoryPerformance {
  final String category;
  final int totalSessions;
  final int completedSessions;
  final int accuracyRate; // 0–100
  final int avgResponseTimeMs;
  final int avgScore;
  final int currentLevel;
  final int avgLevel;
  final List<PerformancePoint> timeline;

  const CategoryPerformance({
    required this.category,
    required this.totalSessions,
    required this.completedSessions,
    required this.accuracyRate,
    required this.avgResponseTimeMs,
    required this.avgScore,
    required this.currentLevel,
    required this.avgLevel,
    required this.timeline,
  });

  double get completionRate =>
      totalSessions > 0 ? completedSessions / totalSessions * 100 : 0;

  String get responseTimeFormatted {
    if (avgResponseTimeMs <= 0) return '—';
    if (avgResponseTimeMs < 1000) return '${avgResponseTimeMs}ms';
    return '${(avgResponseTimeMs / 1000).toStringAsFixed(1)}s';
  }
}

@immutable
class RadarAxis {
  final String category;
  final int accuracy; // 0–100
  final int sessions;

  const RadarAxis({
    required this.category,
    required this.accuracy,
    required this.sessions,
  });
}

@immutable
class PerformancePoint {
  final DateTime date;
  final String activityTitle;
  final int? score;
  final int accuracyPct;
  final int responseTimeMs;
  final int difficultyLevel;
  final String difficulty;
  final String status;

  const PerformancePoint({
    required this.date,
    required this.activityTitle,
    this.score,
    required this.accuracyPct,
    required this.responseTimeMs,
    required this.difficultyLevel,
    required this.difficulty,
    required this.status,
  });
}
