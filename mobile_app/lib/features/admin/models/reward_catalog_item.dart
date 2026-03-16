/// UCD027 – Reward Library model for the admin global reward catalog.
///
/// Maps to the `reward_library` table in Supabase.
class RewardCatalogItem {
  final String id;
  final String name;
  final String? description;
  final RewardCategory category;
  final int pointCost;
  final String? iconUrl;
  final String? iconFileName;
  final String? iconFilePath;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RewardCatalogItem({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.pointCost,
    this.iconUrl,
    this.iconFileName,
    this.iconFilePath,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RewardCatalogItem.fromJson(Map<String, dynamic> json) {
    return RewardCatalogItem(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category:
          RewardCategory.fromString(json['category'] as String? ?? 'badge'),
      pointCost: json['point_cost'] as int? ?? 0,
      iconUrl: json['icon_url'] as String?,
      iconFileName: json['icon_file_name'] as String?,
      iconFilePath: json['icon_file_path'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'category': category.value,
      'point_cost': pointCost,
      'icon_url': iconUrl,
      'icon_file_name': iconFileName,
      'icon_file_path': iconFilePath,
      'is_active': isActive,
    };
  }

  RewardCatalogItem copyWith({
    String? name,
    String? description,
    RewardCategory? category,
    int? pointCost,
    String? iconUrl,
    String? iconFileName,
    String? iconFilePath,
    bool? isActive,
  }) {
    return RewardCatalogItem(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      pointCost: pointCost ?? this.pointCost,
      iconUrl: iconUrl ?? this.iconUrl,
      iconFileName: iconFileName ?? this.iconFileName,
      iconFilePath: iconFilePath ?? this.iconFilePath,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Whether the icon is available.
  bool get hasIcon => iconUrl != null && iconUrl!.isNotEmpty;

  /// Human-friendly point label.
  String get pointLabel => '$pointCost pts';
}

/// Categories for reward library items – matches UCD027 spec.
enum RewardCategory {
  badge,
  theme,
  sticker;

  String get value {
    switch (this) {
      case RewardCategory.badge:
        return 'badge';
      case RewardCategory.theme:
        return 'theme';
      case RewardCategory.sticker:
        return 'sticker';
    }
  }

  String get label {
    switch (this) {
      case RewardCategory.badge:
        return 'Badge';
      case RewardCategory.theme:
        return 'Theme';
      case RewardCategory.sticker:
        return 'Sticker';
    }
  }

  IconLabel get iconLabel {
    switch (this) {
      case RewardCategory.badge:
        return const IconLabel('🏅', 'Badge');
      case RewardCategory.theme:
        return const IconLabel('🎨', 'Theme');
      case RewardCategory.sticker:
        return const IconLabel('⭐', 'Sticker');
    }
  }

  static RewardCategory fromString(String value) {
    return RewardCategory.values.firstWhere(
      (c) => c.value == value,
      orElse: () => RewardCategory.badge,
    );
  }
}

/// Simple helper for pairing an icon emoji with a text label.
class IconLabel {
  final String icon;
  final String text;
  const IconLabel(this.icon, this.text);
}
