import 'package:flutter/material.dart';

class Emotion {
  final String id;
  final String name;
  final Color color;
  final String emoji;
  final String valence;     // 'positive' | 'negative'
  final int plutchikOrder;  // 1-8

  const Emotion({
    required this.id,
    required this.name,
    required this.color,
    required this.emoji,
    this.valence = 'positive',
    this.plutchikOrder = 1,
  });

  Emotion copyWith({
    String? id,
    String? name,
    Color? color,
    String? emoji,
    String? valence,
    int? plutchikOrder,
  }) {
    return Emotion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      emoji: emoji ?? this.emoji,
      valence: valence ?? this.valence,
      plutchikOrder: plutchikOrder ?? this.plutchikOrder,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color.toARGB32(),
      'emoji': emoji,
      'valence': valence,
      'plutchikOrder': plutchikOrder,
    };
  }

  factory Emotion.fromJson(Map<String, dynamic> json) {
    return Emotion(
      id: json['id'] as String,
      name: json['name'] as String,
      color: Color(json['color'] as int),
      emoji: json['emoji'] as String,
      valence: (json['valence'] as String?) ?? 'positive',
      plutchikOrder: (json['plutchikOrder'] as int?) ?? 1,
    );
  }
}
