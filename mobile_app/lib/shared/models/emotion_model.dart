import 'package:flutter/material.dart';

/// Model for representing a child's personalized emotion
class EmotionModel {
  final String id;
  final String name;
  final Color color;
  final IconData? icon;
  final DateTime createdAt;
  final DateTime? updatedAt;

  EmotionModel({
    required this.id,
    required this.name,
    required this.color,
    this.icon,
    required this.createdAt,
    this.updatedAt,
  });

  factory EmotionModel.fromJson(Map<String, dynamic> json) {
    return EmotionModel(
      id: json['id'] as String,
      name: json['emotion_name'] as String,
      color: Color(int.parse(json['color_hex'].replaceFirst('#', '0xFF'))),
      icon: json['icon'] != null ? _parseIcon(json['icon']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'emotion_name': name,
      'color_hex':
          '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
      'icon': icon?.codePoint.toString(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static IconData? _parseIcon(String iconCode) {
    try {
      return IconData(int.parse(iconCode), fontFamily: 'MaterialIcons');
    } catch (e) {
      return null;
    }
  }

  EmotionModel copyWith({
    String? id,
    String? name,
    Color? color,
    IconData? icon,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmotionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
