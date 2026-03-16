/// UCD019 – Content asset model for the global content library.
///
/// Maps to the `content_assets` table in Supabase.
class ContentAsset {
  final String id;
  final String title;
  final String? description;
  final AssetCategory category;
  final String fileUrl;
  final String fileName;
  final String mimeType;
  final int fileSizeBytes;
  final String? tag;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ContentAsset({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.fileUrl,
    required this.fileName,
    required this.mimeType,
    required this.fileSizeBytes,
    this.tag,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ContentAsset.fromJson(Map<String, dynamic> json) {
    return ContentAsset(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category:
          AssetCategory.fromString(json['category'] as String? ?? 'other'),
      fileUrl: json['file_url'] as String,
      fileName: json['file_name'] as String,
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
      fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
      tag: json['tag'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'category': category.value,
      'file_url': fileUrl,
      'file_name': fileName,
      'mime_type': mimeType,
      'file_size_bytes': fileSizeBytes,
      'tag': tag,
      'is_active': isActive,
    };
  }

  ContentAsset copyWith({
    String? title,
    String? description,
    AssetCategory? category,
    String? tag,
    bool? isActive,
  }) {
    return ContentAsset(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      fileUrl: fileUrl,
      fileName: fileName,
      mimeType: mimeType,
      fileSizeBytes: fileSizeBytes,
      tag: tag ?? this.tag,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// True when the stored file is an image (PNG/JPG/JPEG/GIF/WEBP).
  bool get isImage {
    final lower = mimeType.toLowerCase();
    return lower.startsWith('image/');
  }

  /// True when the stored file is audio (MP3/WAV/OGG).
  bool get isAudio {
    final lower = mimeType.toLowerCase();
    return lower.startsWith('audio/');
  }

  /// Human-friendly file size string.
  String get fileSizeFormatted {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Asset categories matching the UCD019 spec.
enum AssetCategory {
  rewardIcon,
  activityImage,
  storyTemplate,
  other;

  String get value {
    switch (this) {
      case AssetCategory.rewardIcon:
        return 'reward_icon';
      case AssetCategory.activityImage:
        return 'activity_image';
      case AssetCategory.storyTemplate:
        return 'story_template';
      case AssetCategory.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case AssetCategory.rewardIcon:
        return 'Reward Icon';
      case AssetCategory.activityImage:
        return 'Activity Image';
      case AssetCategory.storyTemplate:
        return 'Story Template';
      case AssetCategory.other:
        return 'Other';
    }
  }

  static AssetCategory fromString(String value) {
    return AssetCategory.values.firstWhere(
      (c) => c.value == value,
      orElse: () => AssetCategory.other,
    );
  }
}
