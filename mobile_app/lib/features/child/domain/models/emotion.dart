import 'package:flutter/material.dart';

class Emotion {
  final String id;
  final String name;
  final Color color;
  final String emoji;

  const Emotion({
    required this.id,
    required this.name,
    required this.color,
    required this.emoji,
  });

  Emotion copyWith({
    String? id,
    String? name,
    Color? color,
    String? emoji,
  }) {
    return Emotion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      emoji: emoji ?? this.emoji,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color.toARGB32(),
      'emoji': emoji,
    };
  }

  factory Emotion.fromJson(Map<String, dynamic> json) {
    return Emotion(
      id: json['id'],
      name: json['name'],
      color: Color(json['color']),
      emoji: json['emoji'],
    );
  }
}
