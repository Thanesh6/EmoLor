/// Model for gamified learning activities
class ActivityModel {
  final String id;
  final String title;
  final String description;
  final ActivityType type;
  final int ageRangeMin;
  final int ageRangeMax;
  final int durationMinutes;
  final DifficultyLevel difficulty;
  final String? thumbnailUrl;
  final Map<String, dynamic>? contentData;
  final bool isActive;
  final DateTime createdAt;

  ActivityModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.ageRangeMin,
    required this.ageRangeMax,
    required this.durationMinutes,
    required this.difficulty,
    this.thumbnailUrl,
    this.contentData,
    this.isActive = true,
    required this.createdAt,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      type: ActivityType.fromString(json['activity_type'] as String? ?? 'game'),
      ageRangeMin: json['age_range_min'] as int? ?? 0,
      ageRangeMax: json['age_range_max'] as int? ?? 18,
      durationMinutes: json['duration_minutes'] as int? ?? 15,
      difficulty:
          DifficultyLevel.fromString(json['difficulty'] as String? ?? 'easy'),
      thumbnailUrl: json['thumbnail_url'] as String?,
      contentData: json['content_data'] as Map<String, dynamic>?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'activity_type': type.value,
      'age_range_min': ageRangeMin,
      'age_range_max': ageRangeMax,
      'duration_minutes': durationMinutes,
      'difficulty': difficulty.value,
      'thumbnail_url': thumbnailUrl,
      'content_data': contentData,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

enum ActivityType {
  game,
  exercise,
  story,
  art;

  String get value => name;

  static ActivityType fromString(String value) {
    return ActivityType.values.firstWhere(
      (type) => type.name == value.toLowerCase(),
      orElse: () => ActivityType.game,
    );
  }
}

enum DifficultyLevel {
  easy,
  medium,
  hard;

  String get value => name;

  static DifficultyLevel fromString(String value) {
    return DifficultyLevel.values.firstWhere(
      (level) => level.name == value.toLowerCase(),
      orElse: () => DifficultyLevel.easy,
    );
  }
}
