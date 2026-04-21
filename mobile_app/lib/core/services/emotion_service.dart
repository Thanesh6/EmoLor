import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  /// The 8 emotions children map colours to.
  /// Order matches the My Colours onboarding flow:
  ///   1-4 Positive, 5-8 Negative.
  static const List<Emotion> _defaults = [
    Emotion(id: 'happy',   name: 'Happy',   color: Color(0xFFFFB088), emoji: '😄', valence: 'positive', plutchikOrder: 1),
    Emotion(id: 'loved',   name: 'Loved',   color: Color(0xFFFF7EB3), emoji: '🤗', valence: 'positive', plutchikOrder: 2),
    Emotion(id: 'excited', name: 'Excited', color: Color(0xFFFF9F43), emoji: '🤩', valence: 'positive', plutchikOrder: 3),
    Emotion(id: 'calm',    name: 'Calm',    color: Color(0xFF4ECDC4), emoji: '😌', valence: 'positive', plutchikOrder: 4),
    Emotion(id: 'sad',     name: 'Sad',     color: Color(0xFF74B9FF), emoji: '😢', valence: 'negative', plutchikOrder: 5),
    Emotion(id: 'scared',  name: 'Scared',  color: Color(0xFFBB6BD9), emoji: '😰', valence: 'negative', plutchikOrder: 6),
    Emotion(id: 'tired',   name: 'Tired',   color: Color(0xFF9CA3AF), emoji: '😴', valence: 'negative', plutchikOrder: 7),
    Emotion(id: 'angry',   name: 'Angry',   color: Color(0xFFEF4444), emoji: '😠', valence: 'negative', plutchikOrder: 8),
  ];

  static List<Emotion> get defaultEmotions => _defaults;

  static Future<List<Emotion>> loadEmotionsStatic() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(_storageKey);
    if (stored != null) {
      try {
        final List<dynamic> decoded = jsonDecode(stored);
        final loaded = decoded.map((e) => Emotion.fromJson(e as Map<String, dynamic>)).toList();
        // Merge with defaults to handle new fields (valence, plutchikOrder)
        return _mergeWithDefaults(loaded);
      } catch (_) {
        return List.from(_defaults);
      }
    }
    return List.from(_defaults);
  }

  /// Merge loaded emotions with defaults — ensures new emotions that were
  /// added after initial onboarding still appear, and that valence/order
  /// are always present even on old SharedPreferences data.
  static List<Emotion> _mergeWithDefaults(List<Emotion> loaded) {
    return _defaults.map((def) {
      try {
        final saved = loaded.firstWhere((e) => e.id == def.id);
        return def.copyWith(color: saved.color);
      } catch (_) {
        return def;
      }
    }).toList();
  }

  Future<void> _loadEmotions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(_storageKey);
    if (stored != null) {
      try {
        final List<dynamic> decoded = jsonDecode(stored);
        final loaded = decoded.map((e) => Emotion.fromJson(e as Map<String, dynamic>)).toList();
        state = _mergeWithDefaults(loaded);
      } catch (_) {
        state = List.from(_defaults);
      }
    } else {
      state = List.from(_defaults);
    }
    await EmotionColourMapping.load();
  }

  Future<void> updateEmotionColor(String id, Color newColor) async {
    state = [
      for (final emotion in state)
        if (emotion.id == id) emotion.copyWith(color: newColor) else emotion,
    ];
    await _saveEmotions();
  }

  /// Save all 8 colour mappings at once (used by My Colours summary screen).
  Future<void> saveAllColors(List<Emotion> emotions) async {
    state = emotions;
    await _saveEmotions();
    // Sync to Supabase emotion_colors table
    await _syncToSupabase(emotions);
  }

  Future<void> _saveEmotions() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
    await EmotionColourMapping.load();
  }

  Future<void> _syncToSupabase(List<Emotion> emotions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final childProfileId = prefs.getString('selected_child_profile_id');
      if (childProfileId == null || childProfileId.isEmpty) return;

      final client = Supabase.instance.client;
      for (final e in emotions) {
        final hex = '#${e.color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
        await client.rpc('upsert_emotion_color', params: {
          'p_child_profile_id': childProfileId,
          'p_emotion_name': e.name,
          'p_color_hex': hex,
          'p_icon': e.emoji,
          'p_valence': e.valence,
          'p_plutchik_order': e.plutchikOrder,
        });
      }
    } catch (e) {
      // Non-critical — local data is source of truth
      debugPrint('EmotionService._syncToSupabase: $e');
    }
  }

  Future<void> resetToDefaults() async {
    state = List.from(_defaults);
    await _saveEmotions();
  }

  Color getColorForEmotion(String id) {
    return state
        .firstWhere((e) => e.id == id, orElse: () => _defaults.first)
        .color;
  }

  // ── Assigned-IDs tracking ──────────────────────────────────────────────────

  static const String _assignedKey = 'assigned_emotion_ids';

  /// Returns the Set of emotion IDs that have been explicitly colour-picked
  /// by the child (either via My Colours or during session flow).
  static Future<Set<String>> getAssignedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return Set<String>.from(prefs.getStringList(_assignedKey) ?? []);
  }

  /// Marks one emotion ID as user-assigned.
  static Future<void> markAssigned(String emotionId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = List<String>.from(prefs.getStringList(_assignedKey) ?? []);
    if (!current.contains(emotionId)) {
      current.add(emotionId);
      await prefs.setStringList(_assignedKey, current);
    }
  }

  /// Marks ALL 8 emotions as assigned (called after My Colours is completed).
  static Future<void> markAllAssigned() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_assignedKey, _defaults.map((e) => e.id).toList());
  }

  /// Save a single emotion colour during session flow (lighter than saveAllColors).
  static Future<void> saveSingleColorStatic(String emotionId, Color color) async {
    final prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(_storageKey);
    List<Emotion> emotions = List.from(_defaults);
    if (stored != null) {
      try {
        final decoded = jsonDecode(stored) as List<dynamic>;
        emotions = _mergeWithDefaults(
          decoded.map((e) => Emotion.fromJson(e as Map<String, dynamic>)).toList(),
        );
      } catch (_) {}
    }
    emotions = emotions.map((e) => e.id == emotionId ? e.copyWith(color: color) : e).toList();
    await prefs.setString(_storageKey, jsonEncode(emotions.map((e) => e.toJson()).toList()));
    await markAssigned(emotionId);
    await EmotionColourMapping.load();
    await _syncSingleToSupabase(emotions, emotionId, color);
  }

  static Future<void> _syncSingleToSupabase(List<Emotion> emotions, String emotionId, Color color) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final childProfileId = prefs.getString('selected_child_profile_id');
      if (childProfileId == null || childProfileId.isEmpty) return;
      final emotion = emotions.firstWhere((e) => e.id == emotionId, orElse: () => _defaults.first);
      final hex = '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
      await Supabase.instance.client.rpc('upsert_emotion_color', params: {
        'p_child_profile_id': childProfileId,
        'p_emotion_name': emotion.name,
        'p_color_hex': hex,
        'p_icon': emotion.emoji,
        'p_valence': emotion.valence,
        'p_plutchik_order': emotion.plutchikOrder,
      });
    } catch (e) {
      debugPrint('EmotionService._syncSingleToSupabase: $e');
    }
  }

  Emotion? findDuplicateColour(Color color, {required String excludeId}) {
    for (final e in state) {
      if (e.id == excludeId) continue;
      if (e.color.toARGB32() == color.toARGB32()) return e;
    }
    return null;
  }
}
