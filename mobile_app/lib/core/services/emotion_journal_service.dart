import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Logs every emoji interaction during gameplay.
/// Caregivers can view this data to understand which emotions
/// the child engages with most frequently.
///
/// Scoped by `selected_child_profile_id` so siblings under the same
/// caregiver/org account each maintain their own emotion journal — the
/// previous behaviour (keyed by caregiver Supabase UID) caused all child
/// profiles to share analytics.
class EmotionJournalService {
  EmotionJournalService._();

  static const String _storageKey = 'emotion_journal';
  static const String _profileIdKey = 'selected_child_profile_id';
  static const int _maxEntries = 500; // Keep last 500 interactions

  static Future<String> _scopeKey() async {
    final prefs = await SharedPreferences.getInstance();
    final profileId = prefs.getString(_profileIdKey) ?? 'no_profile';
    return '${_storageKey}_$profileId';
  }

  /// Log a single emoji interaction for the current child profile.
  static Future<void> log({
    required String emoji,
    required String emotionName,
    required String category,
    required String gameId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _scopeKey();
    final entries = _loadEntriesForKey(prefs, key);

    entries.add({
      'emoji': emoji,
      'emotion': emotionName,
      'category': category,
      'game': gameId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });

    if (entries.length > _maxEntries) {
      entries.removeRange(0, entries.length - _maxEntries);
    }

    await prefs.setString(key, jsonEncode(entries));
  }

  /// Load all journal entries for the current child profile.
  static Future<List<Map<String, dynamic>>> getEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _scopeKey();
    return _loadEntriesForKey(prefs, key);
  }

  /// Load entries for a specific child profile (for caregiver viewing).
  static Future<List<Map<String, dynamic>>> getEntriesForProfile(
      String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    return _loadEntriesForKey(prefs, '${_storageKey}_$profileId');
  }

  static List<Map<String, dynamic>> _loadEntriesForKey(
      SharedPreferences prefs, String key) {
    final stored = prefs.getString(key);
    if (stored == null) return [];
    try {
      final decoded = jsonDecode(stored) as List;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Get summary analytics: emotion frequency counts.
  static Future<Map<String, int>> getEmotionFrequency() async {
    final entries = await getEntries();
    final freq = <String, int>{};
    for (final e in entries) {
      final emotion = e['emotion'] as String;
      freq[emotion] = (freq[emotion] ?? 0) + 1;
    }
    return freq;
  }

  /// Get summary analytics: category frequency counts.
  static Future<Map<String, int>> getCategoryFrequency() async {
    final entries = await getEntries();
    final freq = <String, int>{};
    for (final e in entries) {
      final cat = e['category'] as String;
      freq[cat] = (freq[cat] ?? 0) + 1;
    }
    return freq;
  }

  /// Get summary analytics: game frequency counts.
  static Future<Map<String, int>> getGameFrequency() async {
    final entries = await getEntries();
    final freq = <String, int>{};
    for (final e in entries) {
      final game = e['game'] as String;
      freq[game] = (freq[game] ?? 0) + 1;
    }
    return freq;
  }

  /// Get entries filtered by date range.
  static Future<List<Map<String, dynamic>>> getEntriesByDateRange(
      DateTime start, DateTime end) async {
    final entries = await getEntries();
    return entries.where((e) {
      final ts = DateTime.parse(e['timestamp'] as String);
      return ts.isAfter(start) && ts.isBefore(end);
    }).toList();
  }

  /// Get daily emotion breakdown for the last N days.
  static Future<Map<String, Map<String, int>>> getDailyBreakdown({int days = 7}) async {
    final now = DateTime.now().toUtc();
    final start = now.subtract(Duration(days: days));
    final entries = await getEntriesByDateRange(start, now);

    final breakdown = <String, Map<String, int>>{};
    for (final e in entries) {
      final ts = DateTime.parse(e['timestamp'] as String);
      final dayKey = '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';
      final emotion = e['emotion'] as String;
      breakdown.putIfAbsent(dayKey, () => {});
      breakdown[dayKey]![emotion] = (breakdown[dayKey]![emotion] ?? 0) + 1;
    }
    return breakdown;
  }

  /// Clear all journal entries for the current child profile.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _scopeKey();
    await prefs.remove(key);
  }
}
