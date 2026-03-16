class Activity {
  final String id;
  final String title;
  final String description;
  final String type; // 'game', 'story', 'music', 'art'
  final String difficulty; // 'easy', 'medium', 'hard'
  final int durationMinutes;
  final String? thumbnailUrl;
  final Map<String, dynamic> contentData;

  Activity({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.difficulty,
    required this.durationMinutes,
    this.thumbnailUrl,
    this.contentData = const {},
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      type: json['activity_type'] as String,
      difficulty: json['difficulty'] as String? ?? 'easy',
      durationMinutes: json['duration_minutes'] as int? ?? 5,
      thumbnailUrl: json['thumbnail_url'] as String?,
      contentData: json['content_data'] as Map<String, dynamic>? ?? {},
    );
  }
}
