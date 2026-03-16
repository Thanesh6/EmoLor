import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight static accessor for the personalized emotion-colour map.
///
/// Reads from the same SharedPreferences key that [EmotionService] writes
/// to (`user_emotions_palette`), so any change persisted by the service is
/// automatically picked up on the next [load] call.
///
/// Game screens call [colorFor] during `initState` / `build` to resolve
/// the user's chosen colour for a given emotion name — no Riverpod needed.
class EmotionColourMapping {
  EmotionColourMapping._();

  static const String _storageKey = 'user_emotions_palette';

  // ── Default colours — Plutchik's 8 primary emotions ──
  static const Map<String, Color> defaults = {
    'Joy': Color(0xFFFFE66D),
    'Trust': Color(0xFF7ED957),
    'Fear': Color(0xFFBB6BD9),
    'Surprise': Color(0xFF06B6D4),
    'Sadness': Color(0xFF74B9FF),
    'Disgust': Color(0xFF84CC16),
    'Anger': Color(0xFFEF4444),
    'Anticipation': Color(0xFFFF9F43),
    // Legacy aliases for backward-compat with existing game screens
    'Happy': Color(0xFFFFE66D),
    'Sad': Color(0xFF74B9FF),
    'Angry': Color(0xFFEF4444),
    'Calm': Color(0xFF7ED957),
    'Scared': Color(0xFFBB6BD9),
    'Excited': Color(0xFFFF9F43),
    'Love': Color(0xFFFF7EB3),
    'Surprised': Color(0xFF06B6D4),
    'Cool': Color(0xFF7ED957),
    'Kind': Color(0xFF4ECDC4),
  };

  /// User-personalised overrides loaded from SharedPreferences.
  static final Map<String, Color> _overrides = {};

  // ── Public API ──

  /// Load personalisation from SharedPreferences.
  /// Call once at app startup and again after every save in MyColoursScreen.
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
      } catch (_) {
        // Corrupted data — fall back to defaults silently.
      }
    }
  }

  /// Return the user's colour for [emotionName], falling back to the
  /// built-in default and then to grey if the name is totally unknown.
  static Color colorFor(String emotionName) {
    return _overrides[emotionName] ??
        defaults[emotionName] ??
        const Color(0xFF999999);
  }

  /// Whether the colour cache has been loaded at least once.
  static bool get isLoaded => _loadedOnce;
  static bool _loadedOnce = false;

  /// Wrapper that sets [_loadedOnce] after [load] completes.
  static Future<void> ensureLoaded() async {
    if (_loadedOnce) return;
    await load();
    _loadedOnce = true;
  }
}
