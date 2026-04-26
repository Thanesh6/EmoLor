import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/completion_record.dart';

/// Offline-first persistence for activity completion records.
///
/// Records are saved to SharedPreferences immediately (step 5 offline
/// alt-flow). When the backend is reachable the data can be synced
/// by calling [syncPending].
class CompletionService {
  static const _profileIdKey = 'selected_child_profile_id';

  static Future<String> _listKeyAsync() async {
    final prefs = await SharedPreferences.getInstance();
    final profileId = prefs.getString(_profileIdKey) ?? 'no_profile';
    return 'completion_records_$profileId';
  }

  /// Persist a new [record] locally.
  static Future<void> save(CompletionRecord record) async {
    final all = await _loadAll();
    all.add(record);
    await _saveAll(all);
  }

  /// Return every record, newest first.
  static Future<List<CompletionRecord>> history() async {
    final all = await _loadAll();
    all.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return all;
  }

  /// Records that have not been synced to the remote database yet.
  static Future<List<CompletionRecord>> pending() async {
    return (await _loadAll()).where((r) => !r.synced).toList();
  }

  /// Mark all pending records as synced (call after successful upload).
  static Future<void> markAllSynced() async {
    final all = await _loadAll();
    final updated = all.map((r) => r.copyWith(synced: true)).toList();
    await _saveAll(updated);
  }

  /// Attempt to sync pending records to the remote database.
  /// Returns `true` if all records were synced.
  ///
  /// For now this is a stub — concrete Supabase upload can be added later
  /// when the backend table is provisioned.
  static Future<bool> syncPending() async {
    final records = await pending();
    if (records.isEmpty) return true;

    // TODO: upload each record to Supabase `activity_completions` table
    // For now, mark them as synced optimistically (offline-first UX).
    // await _uploadToSupabase(records);
    await markAllSynced();
    return true;
  }

  /// Total completions for a given activity.
  static Future<int> completionCount(String activityId) async {
    return (await _loadAll()).where((r) => r.activityId == activityId).length;
  }

  // ── Private helpers ──

  static Future<List<CompletionRecord>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final listKey = await _listKeyAsync();
    final raw = prefs.getString(listKey);
    if (raw == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded
          .map((e) => CompletionRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveAll(List<CompletionRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final listKey = await _listKeyAsync();
    final encoded = jsonEncode(records.map((r) => r.toJson()).toList());
    await prefs.setString(listKey, encoded);
  }

  /// Clear all completion history (used by Reset Game feature).
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final listKey = await _listKeyAsync();
    await prefs.remove(listKey);
  }
}
