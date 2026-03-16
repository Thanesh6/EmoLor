class MoodEntry {
  final String id;
  final String emotionId;
  final DateTime timestamp;

  const MoodEntry({
    required this.id,
    required this.emotionId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'emotionId': emotionId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    return MoodEntry(
      id: json['id'],
      emotionId: json['emotionId'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
