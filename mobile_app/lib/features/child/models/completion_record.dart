import 'dart:convert';

/// A record of a completed activity session, stored locally and synced
/// to the database when connectivity is available.
class CompletionRecord {
  final String activityId;
  final String activityName;
  final int starsEarned;
  final int scoreValue;
  final int scoreMax;
  final int timeSpentSeconds;
  final DateTime completedAt;
  final bool synced;

  const CompletionRecord({
    required this.activityId,
    required this.activityName,
    required this.starsEarned,
    required this.scoreValue,
    required this.scoreMax,
    required this.timeSpentSeconds,
    required this.completedAt,
    this.synced = false,
  });

  CompletionRecord copyWith({bool? synced}) => CompletionRecord(
        activityId: activityId,
        activityName: activityName,
        starsEarned: starsEarned,
        scoreValue: scoreValue,
        scoreMax: scoreMax,
        timeSpentSeconds: timeSpentSeconds,
        completedAt: completedAt,
        synced: synced ?? this.synced,
      );

  Map<String, dynamic> toJson() => {
        'activityId': activityId,
        'activityName': activityName,
        'starsEarned': starsEarned,
        'scoreValue': scoreValue,
        'scoreMax': scoreMax,
        'timeSpentSeconds': timeSpentSeconds,
        'completedAt': completedAt.toIso8601String(),
        'synced': synced,
      };

  factory CompletionRecord.fromJson(Map<String, dynamic> j) => CompletionRecord(
        activityId: j['activityId'] as String,
        activityName: j['activityName'] as String? ?? '',
        starsEarned: j['starsEarned'] as int? ?? 0,
        scoreValue: j['scoreValue'] as int? ?? 0,
        scoreMax: j['scoreMax'] as int? ?? 0,
        timeSpentSeconds: j['timeSpentSeconds'] as int? ?? 0,
        completedAt: DateTime.tryParse(j['completedAt'] as String? ?? '') ??
            DateTime.now(),
        synced: j['synced'] as bool? ?? false,
      );

  String encode() => jsonEncode(toJson());
  static CompletionRecord? decode(String raw) {
    try {
      return CompletionRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
