import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../features/child/domain/models/mood_entry.dart';

final moodServiceProvider = StateNotifierProvider<MoodService, List<MoodEntry>>((ref) {
  return MoodService();
});

class MoodService extends StateNotifier<List<MoodEntry>> {
  MoodService() : super([]) {
    _loadEntries();
  }

  static const String _profileIdKey = 'selected_child_profile_id';

  static Future<String> _storageKeyAsync() async {
    final prefs = await SharedPreferences.getInstance();
    final profileId = prefs.getString(_profileIdKey) ?? 'no_profile';
    return 'user_mood_entries_$profileId';
  }

  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = await _storageKeyAsync();
    final String? stored = prefs.getString(storageKey);

    if (stored != null) {
      try {
        final List<dynamic> decoded = jsonDecode(stored);
        state = decoded.map((e) => MoodEntry.fromJson(e)).toList();
      } catch (e) {
        state = [];
      }
    }
  }

  Future<void> addEntry(String emotionId) async {
    final entry = MoodEntry(
      id: const Uuid().v4(),
      emotionId: emotionId,
      timestamp: DateTime.now(),
    );
    state = [entry, ...state];
    await _saveEntries();
  }

  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = await _storageKeyAsync();
    final String encoded = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString(storageKey, encoded);
  }
}
