import 'package:flutter/foundation.dart';

/// UCD046 – Define Report Parameters
///
/// Shared, immutable filter-parameter object used across the Analytics
/// Dashboard, Engagement Trends, Performance Statistics, and Report
/// Generation screens.
///
/// Holds configurable criteria such as:
///  • Date range (preset or custom start/end)
///  • Activity-type filters (game, exercise, story, art)
///  • Skill-category filters (Emotion Recognition, Social Cues, …)
///  • Comparison metric selector (e.g., accuracy, response time)
///  • Completion-status filter
@immutable
class AnalyticsFilterParams {
  // ── Date range ───────────────────────────────────────────────────────
  /// Preset index: 0 = 7d, 1 = 30d, 2 = 90d, 3 = custom.
  final int rangePreset;

  /// Custom start / end – only used when [rangePreset] == 3.
  final DateTime? customStart;
  final DateTime? customEnd;

  // ── Activity-type filter ─────────────────────────────────────────────
  /// If empty, all types are included (no filter).
  final Set<String> activityTypes;

  // ── Skill-category filter ────────────────────────────────────────────
  /// If empty, all categories are included (no filter).
  final Set<String> skillCategories;

  // ── Completion status ────────────────────────────────────────────────
  /// `null` means no filter (all statuses). Otherwise 'completed', 'started'.
  final String? statusFilter;

  // ── Comparison metric (for potential chart toggling) ─────────────────
  final ComparisonMetric comparisonMetric;

  const AnalyticsFilterParams({
    this.rangePreset = 1,
    this.customStart,
    this.customEnd,
    this.activityTypes = const {},
    this.skillCategories = const {},
    this.statusFilter,
    this.comparisonMetric = ComparisonMetric.accuracy,
  });

  /// Default (no filters applied).
  static const defaultParams = AnalyticsFilterParams();

  // ── Canonical value lists ────────────────────────────────────────────

  static const allActivityTypes = ['game', 'exercise', 'story', 'art'];

  static const allActivityTypeLabels = {
    'game': 'Games',
    'exercise': 'Exercises',
    'story': 'Stories',
    'art': 'Art Activities',
  };

  static const allSkillCategories = [
    'Emotion Recognition',
    'Social Cues',
    'Self-Regulation',
    'Creative Expression',
    'Cognitive Skills',
    'General',
  ];

  static const allStatuses = ['completed', 'started', 'in_progress'];

  // ── Computed date range ──────────────────────────────────────────────

  static const _presetDays = [7, 30, 90];

  DateTime get effectiveStart {
    if (rangePreset == 3 && customStart != null) return customStart!;
    final now = DateTime.now();
    final days = _presetDays[rangePreset.clamp(0, 2)];
    return DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
  }

  DateTime get effectiveEnd {
    if (rangePreset == 3 && customEnd != null) return customEnd!;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  String get rangeLabel {
    const labels = ['Last 7 Days', 'Last 30 Days', 'Last 3 Months', 'Custom'];
    return labels[rangePreset.clamp(0, 3)];
  }

  // ── Validation ───────────────────────────────────────────────────────

  /// Returns an error string if the configuration is invalid, else null.
  String? validate() {
    if (rangePreset == 3) {
      if (customStart == null || customEnd == null) {
        return 'Please select both start and end dates.';
      }
      if (customStart!.isAfter(customEnd!)) {
        return 'Start Date must be before End Date.';
      }
    }
    return null;
  }

  bool get isValid => validate() == null;

  // ── Filter summary (human-readable) ──────────────────────────────────

  int get activeFilterCount {
    int count = 0;
    if (activityTypes.isNotEmpty) count++;
    if (skillCategories.isNotEmpty) count++;
    if (statusFilter != null) count++;
    if (comparisonMetric != ComparisonMetric.accuracy) count++;
    return count;
  }

  bool get hasActiveFilters => activeFilterCount > 0;

  String get filterSummary {
    final parts = <String>[];
    if (activityTypes.isNotEmpty) {
      parts.add('${activityTypes.length} activity type(s)');
    }
    if (skillCategories.isNotEmpty) {
      parts.add('${skillCategories.length} skill category(ies)');
    }
    if (statusFilter != null) {
      parts.add('Status: $statusFilter');
    }
    return parts.isEmpty ? 'No filters' : parts.join(' · ');
  }

  // ── Copy-with ────────────────────────────────────────────────────────

  AnalyticsFilterParams copyWith({
    int? rangePreset,
    DateTime? customStart,
    DateTime? customEnd,
    Set<String>? activityTypes,
    Set<String>? skillCategories,
    String? statusFilter,
    bool clearStatusFilter = false,
    ComparisonMetric? comparisonMetric,
  }) {
    return AnalyticsFilterParams(
      rangePreset: rangePreset ?? this.rangePreset,
      customStart: customStart ?? this.customStart,
      customEnd: customEnd ?? this.customEnd,
      activityTypes: activityTypes ?? this.activityTypes,
      skillCategories: skillCategories ?? this.skillCategories,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      comparisonMetric: comparisonMetric ?? this.comparisonMetric,
    );
  }

  /// Returns a copy with all filters reset (date range preserved).
  AnalyticsFilterParams resetFilters() {
    return AnalyticsFilterParams(
      rangePreset: rangePreset,
      customStart: customStart,
      customEnd: customEnd,
    );
  }
}

/// Metric choices for comparison charts / KPI focus.
enum ComparisonMetric {
  accuracy('Accuracy'),
  responseTime('Response Time'),
  completionRate('Completion Rate'),
  score('Score');

  final String label;
  const ComparisonMetric(this.label);
}
