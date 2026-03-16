/// Represents a single learning activity available to the child.
class ActivityItem {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final ActivityCategory category;
  final List<int> gradientColors; // stored as int for JSON-safety
  final bool isCompleted;
  final bool isSuggested; // highlighted by Adaptive Sensory Engine
  final DateTime? lastPlayedAt;

  const ActivityItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.category,
    required this.gradientColors,
    this.isCompleted = false,
    this.isSuggested = false,
    this.lastPlayedAt,
  });

  ActivityItem copyWith({
    bool? isCompleted,
    bool? isSuggested,
    DateTime? lastPlayedAt,
  }) {
    return ActivityItem(
      id: id,
      name: name,
      emoji: emoji,
      description: description,
      category: category,
      gradientColors: gradientColors,
      isCompleted: isCompleted ?? this.isCompleted,
      isSuggested: isSuggested ?? this.isSuggested,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    );
  }
}

enum ActivityCategory {
  games,
  drawing,
  stories,
}

String categoryLabel(ActivityCategory c) {
  switch (c) {
    case ActivityCategory.games:
      return 'Games';
    case ActivityCategory.drawing:
      return 'Drawing';
    case ActivityCategory.stories:
      return 'Stories';
  }
}

String categoryEmoji(ActivityCategory c) {
  switch (c) {
    case ActivityCategory.games:
      return '🎮';
    case ActivityCategory.drawing:
      return '🖌️';
    case ActivityCategory.stories:
      return '📖';
  }
}
