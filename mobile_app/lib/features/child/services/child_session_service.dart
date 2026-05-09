import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/sensory_palette.dart';

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
  static const _sessionPreEmotionColourKey =
      'current_session_pre_emotion_colour';
  static const _sessionPreZoneKey = 'current_session_pre_zone_value';

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
      debugPrint('recordPreEmotion profileId: $profileId');

      if (profileId == null) {
        debugPrint('recordPreEmotion skipped: profileId is null');
        return;
      }
      // Look up zone value from standardized sensory palette
      final zoneValue = SensoryPalette.zoneFromHex(emotionColourHex);

      final client = Supabase.instance.client;
      final sessionId = await client.rpc('upsert_child_session', params: {
        'p_profile_id': profileId,
        'p_pre_emotion_name': emotionName,
        'p_pre_emotion_colour': emotionColourHex,
        'p_pre_emotion_valence': emotionValence,
        'p_pre_zone_value': zoneValue,
      }) as String;

      debugPrint('recordPreEmotion created sessionId: $sessionId');

      // Also store pre zone locally for mismatch calculation at post-session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingSessionKey, sessionId);
      if (zoneValue != null) {
        await prefs.setInt(_sessionPreZoneKey, zoneValue);
      }
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
      debugPrint('recordPostEmotion pending sessionId: $sessionId');

      if (sessionId == null) {
        debugPrint('recordPostEmotion skipped: pending sessionId is null');
        return;
      }

      // Zone values
      final postZone = SensoryPalette.zoneFromHex(emotionColourHex);
      final preZone = prefs.containsKey(_sessionPreZoneKey)
          ? prefs.getInt(_sessionPreZoneKey)
          : null;

      // Regulation delta: pre - post (positive = calming)
      final delta = SensoryPalette.regulationDelta(
        preZone: preZone,
        postZone: postZone,
      );

      // Sensory mismatch: emotion word zone vs color zone
      // Map valence to approximate zone for mismatch check
      final emotionZone = _valenceToZone(emotionValence);
      final mismatch = (postZone != null && emotionZone != null)
          ? SensoryPalette.isSensoryMismatch(
              emotionZone: emotionZone,
              colorZone: postZone,
            )
          : false;

      final client = Supabase.instance.client;
      await client.rpc('upsert_child_session', params: {
        'p_session_id': sessionId,
        'p_profile_id': await getChildProfileId(),
        'p_post_emotion_name': emotionName,
        'p_post_emotion_colour': emotionColourHex,
        'p_post_emotion_valence': emotionValence,
        'p_post_zone_value': postZone,
        'p_regulation_delta': delta,
        'p_sensory_mismatch': mismatch,
      });

      debugPrint('recordPostEmotion updated sessionId: $sessionId');

      // Clear pending session and pre zone
      await prefs.remove(_pendingSessionKey);
      await prefs.remove(_sessionPreZoneKey);
    } catch (e) {
      debugPrint('ChildSessionService.recordPostEmotion: $e');
    }
  }

  /// Map emotion valence string to approximate zone value for mismatch check.
  static int? _valenceToZone(String valence) {
    switch (valence.toLowerCase()) {
      case 'positive':
        return 0; // Baseline — happy, calm, loved
      case 'negative_high': // angry, scared, excited (high arousal)
        return 3;
      case 'negative_low': // sad, tired, disgusted (low arousal)
        return -1;
      case 'neutral':
        return 0;
      default:
        return null;
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
      final rows = await client.rpc('get_child_sessions', params: {
        'p_profile_id': profileId,
        'p_limit': limit,
      });

      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) {
      debugPrint('ChildSessionService.getRecentSessions: $e');
      return [];
    }
  }
}
