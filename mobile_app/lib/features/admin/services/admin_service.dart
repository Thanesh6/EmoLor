import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/supabase_service.dart';

/// Service for admin-only operations: list users, toggle active status, audit.
class AdminService {
  final SupabaseClient _client = SupabaseService.client;

  // ── Fetch all profiles (admin sees everyone) ──────────────────────────
  /// Returns a list of all user profiles ordered by full_name.
  /// Each row contains: profile_id, user_id, full_name, role, avatar_url,
  /// phone_number, date_of_birth, is_active.
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .order('full_name', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('AdminService.getAllUsers error: $e');
      rethrow;
    }
  }

  // ── Toggle is_active for a target user ────────────────────────────────
  /// Sets `is_active` to [active] for the profile matching [targetUserId].
  /// Also inserts an audit-log row.
  Future<void> setUserActive({
    required String targetUserId,
    required bool active,
  }) async {
    final adminId = SupabaseService.currentUserId;
    if (adminId == null) throw Exception('Admin not authenticated');

    // 1. Update profile
    await _client
        .from('profiles')
        .update({'is_active': active}).eq('user_id', targetUserId);

    // 2. Write audit log
    await _client.from('admin_audit_log').insert({
      'admin_user_id': adminId,
      'action': active ? 'activate_user' : 'deactivate_user',
      'target_user_id': targetUserId,
      'details': {
        'new_status': active ? 'active' : 'deactivated',
        'timestamp': DateTime.now().toIso8601String(),
      },
    });
  }

  // ── Fetch audit log ───────────────────────────────────────────────────
  /// Returns recent audit-log entries (newest first), limited to [limit].
  Future<List<Map<String, dynamic>>> getAuditLog({int limit = 50}) async {
    try {
      final response = await _client
          .from('admin_audit_log')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('AdminService.getAuditLog error: $e');
      return [];
    }
  }

  // ── UCD010 – Dashboard statistics ─────────────────────────────────────

  /// Fetches a single integer count from [table] with optional filters.
  /// Returns null on failure so the UI can show "Data unavailable".
  Future<int?> _countRows(
    String table, {
    Map<String, dynamic>? eqFilters,
  }) async {
    try {
      var query = _client.from(table).select();
      if (eqFilters != null) {
        for (final entry in eqFilters.entries) {
          query = query.eq(entry.key, entry.value);
        }
      }
      final rows = await query;
      return (rows as List).length;
    } catch (e) {
      debugPrint('AdminService._countRows($table) error: $e');
      return null; // Alt-flow: Data unavailable
    }
  }

  /// Returns a map of dashboard metric keys → nullable int values.
  /// A null value means the metric failed to load (alt-flow: error widget).
  ///
  /// Keys:
  ///   totalUsers, activeCaregivers, activeTherapists, activeChildren,
  ///   deactivatedUsers, recentlyDeactivated
  Future<Map<String, int?>> getDashboardStats() async {
    // Fire all queries in parallel for speed
    final results = await Future.wait([
      _countRows('profiles'), // 0 totalUsers
      _countRows('profiles',
          eqFilters: {'role': 'caregiver', 'is_active': true}), // 1
      _countRows('profiles',
          eqFilters: {'role': 'therapist', 'is_active': true}), // 2
      _countRows('profiles',
          eqFilters: {'role': 'child', 'is_active': true}), // 3
      _countRows('profiles', eqFilters: {'is_active': false}), // 4
      _countRecentlyDeactivated(), // 5
    ]);

    return {
      'totalUsers': results[0],
      'activeCaregivers': results[1],
      'activeTherapists': results[2],
      'activeChildren': results[3],
      'deactivatedUsers': results[4],
      'recentlyDeactivated': results[5],
    };
  }

  /// Count users deactivated in the last 7 days via audit log.
  Future<int?> _countRecentlyDeactivated() async {
    try {
      final sevenDaysAgo =
          DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
      final rows = await _client
          .from('admin_audit_log')
          .select()
          .eq('action', 'deactivate_user')
          .gte('created_at', sevenDaysAgo);
      return (rows as List).length;
    } catch (e) {
      debugPrint('AdminService._countRecentlyDeactivated error: $e');
      return null;
    }
  }
}
