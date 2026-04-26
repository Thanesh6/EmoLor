import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages child app-usage sessions in Supabase `child_sessions` table.
///
/// Each session captures:
///   • Pre-session emotion (how the child felt BEFORE using the app)
///   • Post-session emotion (how the child felt AFTER using the app)
///
/// This enables analytics on whether EmoLor sessions improve emotional state.
class ChildSessionService {
  static const _pendingSessionKey = 'pending_child_session_id';
  static const _profileIdKey = 'selected_child_profile_id';

  // Per-session pre-emotion (cleared at end of every session). The UI uses
  // these to colour the matching emotion card on the post-session screen
  // without polluting the persistent personalized palette.
  static const _sessionPreEmotionIdKey = 'current_session_pre_emotion_id';
  static const _sessionPreEmotionColourKey = 'current_session_pre_emotion_colour';

  /// Save the colour the child just picked for their pre-session emotion.
  /// Stored only for the duration of this session.
  static Future<void> setSessionPreEmotion({
    required String emotionId,
    required String colourHex,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionPreEmotionIdKey, emotionId);
    await prefs.setString(_sessionPreEmotionColourKey, colourHex);
  }

  /// Read the current session's pre-emotion id + colour, if any.
  static Future<({String? emotionId, String? colourHex})>
      getSessionPreEmotion() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      emotionId: prefs.getString(_sessionPreEmotionIdKey),
      colourHex: prefs.getString(_sessionPreEmotionColourKey),
    );
  }

  /// Wipe the current session's pre-emotion. Called from the post-session
  /// screen once the child has completed the loop.
  static Future<void> clearSessionPreEmotion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionPreEmotionIdKey);
    await prefs.remove(_sessionPreEmotionColourKey);
  }

  // ── Profile ID helpers ───────────────────────────────────────────

  static Future<String?> getChildProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_profileIdKey);
  }

  static Future<void> saveChildProfileId(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileIdKey, profileId);
  }

  // ── Session lifecycle ────────────────────────────────────────────

  /// Called when child selects pre-session emotion (how-i-feel-start).
  /// Creates a new child_sessions row and stores the ID locally.
  static Future<void> recordPreEmotion({
    required String emotionName,
    required String emotionValence,
    required String emotionColourHex,
  }) async {
    try {
      final profileId = await getChildProfileId();
      if (profileId == null) return;

      final client = Supabase.instance.client;
      final row = await client.from('child_sessions').insert({
        'child_profile_id': profileId,
        'pre_emotion_name': emotionName,
        'pre_emotion_valence': emotionValence,
        'pre_emotion_colour': emotionColourHex,
        'session_date': DateTime.now().toIso8601String(),
      }).select('id').single();

      final sessionId = row['id'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingSessionKey, sessionId);
    } catch (e) {
      debugPrint('ChildSessionService.recordPreEmotion: $e');
    }
  }

  /// Called when child selects post-session emotion (how-i-feel-end).
  /// Updates the pending session row with post-session data.
  static Future<void> recordPostEmotion({
    required String emotionName,
    required String emotionValence,
    required String emotionColourHex,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(_pendingSessionKey);
      if (sessionId == null) return;

      final client = Supabase.instance.client;
      await client.from('child_sessions').update({
        'post_emotion_name': emotionName,
        'post_emotion_valence': emotionValence,
        'post_emotion_colour': emotionColourHex,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', sessionId);

      // Clear the pending session
      await prefs.remove(_pendingSessionKey);
    } catch (e) {
      debugPrint('ChildSessionService.recordPostEmotion: $e');
    }
  }

  // ── Analytics queries ────────────────────────────────────────────

  /// Returns recent sessions for analytics charts.
  /// Returns list of maps with keys: pre_emotion_name, pre_emotion_valence,
  /// pre_emotion_colour, post_emotion_name, post_emotion_valence,
  /// post_emotion_colour, session_date.
  static Future<List<Map<String, dynamic>>> getRecentSessions({
    int limit = 30,
  }) async {
    try {
      final profileId = await getChildProfileId();
      if (profileId == null) return [];

      final client = Supabase.instance.client;
      final rows = await client
          .from('child_sessions')
          .select()
          .eq('child_profile_id', profileId)
          .order('session_date', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) {
      debugPrint('ChildSessionService.getRecentSessions: $e');
      return [];
    }
  }
}
