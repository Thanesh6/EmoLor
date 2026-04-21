import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight static accessor for the personalized emotion-colour map.
class EmotionColourMapping {
  EmotionColourMapping._();

  static const String _storageKey = 'user_emotions_palette';

  /// Default colours for the 8 EmoLor emotions.
  static const Map<String, Color> defaults = {
    'Happy':   Color(0xFFFFB088),
    'Loved':   Color(0xFFFF7EB3),
    'Excited': Color(0xFFFF9F43),
    'Calm':    Color(0xFF4ECDC4),
    'Sad':     Color(0xFF74B9FF),
    'Scared':  Color(0xFFBB6BD9),
    'Tired':   Color(0xFF9CA3AF),
    'Angry':   Color(0xFFEF4444),
    // Legacy Plutchik aliases kept for backward-compat with game screens
    'Joy':         Color(0xFFFFB088),
    'Trust':       Color(0xFF4ECDC4),
    'Fear':        Color(0xFFBB6BD9),
    'Surprise':    Color(0xFFFF9F43),
    'Sadness':     Color(0xFF74B9FF),
    'Disgust':     Color(0xFF9CA3AF),
    'Anger':       Color(0xFFEF4444),
    'Anticipation':Color(0xFFFF9F43),
    'Proud':   Color(0xFF7ED957),
    'Shy':     Color(0xFFFDAA94),
    'Silly':   Color(0xFF00CEC9),
    'Confused':Color(0xFFA29BFE),
  };

  static final Map<String, Color> _overrides = {};

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(_storageKey);
    _overrides.clear();
    if (stored != null) {
      try {
        final List<dynamic> decoded = jsonDecode(stored);
        for (final e in decoded) {
          _overrides[e['name'] as String] = Color(e['color'] as int);
        }
      } catch (_) {}
    }
    _loadedOnce = true;
  }

  static Color colorFor(String emotionName) {
    return _overrides[emotionName] ??
        defaults[emotionName] ??
        const Color(0xFF999999);
  }

  static String hexFor(String emotionName) {
    final c = colorFor(emotionName);
    return '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  static String valenceFor(String emotionName) {
    const positives = {'Happy', 'Loved', 'Excited', 'Calm', 'Joy', 'Trust', 'Anticipation', 'Surprise', 'Proud', 'Silly'};
    const negatives = {'Sad', 'Scared', 'Tired', 'Angry', 'Sadness', 'Fear', 'Disgust', 'Anger', 'Confused', 'Shy'};
    if (positives.contains(emotionName)) return 'positive';
    if (negatives.contains(emotionName)) return 'negative';
    return 'neutral';
  }

  static bool get isLoaded => _loadedOnce;
  static bool _loadedOnce = false;

  static Future<void> ensureLoaded() async {
    if (_loadedOnce) return;
    await load();
  }
}
