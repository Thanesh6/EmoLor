import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

/// Logs every emoji interaction during gameplay.
/// Caregivers can view this data to understand which emotions
/// the child engages with most frequently.
class EmotionJournalService {
  EmotionJournalService._();

  static const String _storageKey = 'emotion_journal';
  static const int _maxEntries = 500; // Keep last 500 interactions

  /// Log a single emoji interaction.
  static Future<void> log({
    required String emoji,
    required String emotionName,
    required String category,
    required String gameId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await _loadEntries(prefs);

    final userId = SupabaseService.currentUserId ?? 'anon';

    entries.add({
      'emoji': emoji,
      'emotion': emotionName,
      'category': category,
      'game': gameId,
      'userId': userId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });

    // Trim to max entries
    if (entries.length > _maxEntries) {
      entries.removeRange(0, entries.length - _maxEntries);
    }

    await prefs.setString(
      '${_storageKey}_$userId',
      jsonEncode(entries),
    );
  }

  /// Load all journal entries for the current user.
  static Future<List<Map<String, dynamic>>> getEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = SupabaseService.currentUserId ?? 'anon';
    return _loadEntriesForUser(prefs, userId);
  }

  /// Load entries for a specific user (for caregiver viewing).
  static Future<List<Map<String, dynamic>>> getEntriesForUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return _loadEntriesForUser(prefs, userId);
  }

  static Future<List<Map<String, dynamic>>> _loadEntries(SharedPreferences prefs) async {
    final userId = SupabaseService.currentUserId ?? 'anon';
    return _loadEntriesForUser(prefs, userId);
  }

  static List<Map<String, dynamic>> _loadEntriesForUser(SharedPreferences prefs, String userId) {
    final stored = prefs.getString('${_storageKey}_$userId');
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
}
