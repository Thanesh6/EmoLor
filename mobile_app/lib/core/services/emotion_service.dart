import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/child/domain/models/emotion.dart';
import 'emotion_colour_mapping.dart';

final emotionServiceProvider =
    StateNotifierProvider<EmotionService, List<Emotion>>((ref) {
  return EmotionService();
});

class EmotionService extends StateNotifier<List<Emotion>> {
  EmotionService() : super([]) {
    _loadEmotions();
  }

  static const String _storageKey = 'user_emotions_palette';

  // Default emotions — Plutchik's 8 primary emotions with child-friendly
  // colours and emojis.
  static const List<Emotion> _defaults = [
    Emotion(id: 'joy', name: 'Joy', color: Color(0xFFFFE66D), emoji: '😊'),
    Emotion(id: 'trust', name: 'Trust', color: Color(0xFF7ED957), emoji: '🤝'),
    Emotion(id: 'fear', name: 'Fear', color: Color(0xFFBB6BD9), emoji: '😨'),
    Emotion(
        id: 'surprise',
        name: 'Surprise',
        color: Color(0xFF06B6D4),
        emoji: '😲'),
    Emotion(
        id: 'sadness', name: 'Sadness', color: Color(0xFF74B9FF), emoji: '😢'),
    Emotion(
        id: 'disgust', name: 'Disgust', color: Color(0xFF84CC16), emoji: '🤢'),
    Emotion(id: 'anger', name: 'Anger', color: Color(0xFFEF4444), emoji: '😠'),
    Emotion(
        id: 'anticipation',
        name: 'Anticipation',
        color: Color(0xFFFF9F43),
        emoji: '🤩'),
  ];

  /// Public accessor for default emotions (used by progress dashboard).
  static List<Emotion> get defaultEmotions => _defaults;

  /// Static helper to load the emotion palette from SharedPreferences
  /// without requiring a Riverpod ref.
  static Future<List<Emotion>> loadEmotionsStatic() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(_storageKey);
    if (stored != null) {
      try {
        final List<dynamic> decoded = jsonDecode(stored);
        return decoded.map((e) => Emotion.fromJson(e)).toList();
      } catch (_) {
        return _defaults;
      }
    }
    return _defaults;
  }

  Future<void> _loadEmotions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(_storageKey);

    if (stored != null) {
      try {
        final List<dynamic> decoded = jsonDecode(stored);
        state = decoded.map((e) => Emotion.fromJson(e)).toList();
      } catch (e) {
        // Fallback to defaults if error
        state = _defaults;
      }
    } else {
      state = _defaults;
    }
    // Keep the static colour cache in sync.
    await EmotionColourMapping.load();
  }

  Future<void> updateEmotionColor(String id, Color newColor) async {
    state = [
      for (final emotion in state)
        if (emotion.id == id) emotion.copyWith(color: newColor) else emotion,
    ];
    await _saveEmotions();
  }

  Future<void> _saveEmotions() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
    // Refresh the static colour cache so game screens pick up changes.
    await EmotionColourMapping.load();
  }

  Future<void> resetToDefaults() async {
    state = _defaults;
    await _saveEmotions();
  }

  Color getColorForEmotion(String id) {
    return state
        .firstWhere((e) => e.id == id, orElse: () => _defaults.first)
        .color;
  }

  /// Returns the [Emotion] that already uses [color], or `null` if the
  /// colour is free. Excludes the emotion with [excludeId] from the check
  /// so the "self" emotion doesn't flag itself.
  Emotion? findDuplicateColour(Color color, {required String excludeId}) {
    for (final e in state) {
      if (e.id == excludeId) continue;
      if (e.color.toARGB32() == color.toARGB32()) return e;
    }
    return null;
  }
}
