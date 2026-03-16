import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../models/communication_config.dart';

/// UCD036 – Manage Communication Settings
///
/// Reads and writes the `communication_config` table which holds
/// global messaging / media constraints as key→JSONB rows.
class CommunicationConfigService {
  final SupabaseClient _client = SupabaseService.client;

  static const _table = 'communication_config';

  // ── Read ──────────────────────────────────────────────────────────────

  /// Fetches all config rows and returns a typed [CommunicationConfig].
  Future<CommunicationConfig> getConfig() async {
    try {
      final rows = await _client.from(_table).select();
      return CommunicationConfig.fromRows(
        List<Map<String, dynamic>>.from(rows),
      );
    } catch (e) {
      debugPrint('CommunicationConfigService.getConfig error: $e');
      // Return defaults on failure so the form still renders
      return const CommunicationConfig();
    }
  }

  // ── Write ─────────────────────────────────────────────────────────────

  /// Saves the [config] back to the database.
  ///
  /// Each key is upserted individually so we only touch changed rows and
  /// always satisfy the PRIMARY KEY constraint.
  Future<void> saveConfig(CommunicationConfig config) async {
    final adminId = SupabaseService.currentUserId;
    if (adminId == null) throw Exception('Admin not authenticated');

    final entries = config.toKeyValueMap();
    final now = DateTime.now().toUtc().toIso8601String();

    for (final entry in entries.entries) {
      await _client.from(_table).upsert(
        {
          'key': entry.key,
          'value': entry.value, // Supabase auto-wraps primitives as JSONB
          'updated_by': adminId,
          'updated_at': now,
        },
        onConflict: 'key',
      );
    }

    // Audit log
    try {
      await _client.from('admin_audit_log').insert({
        'admin_user_id': adminId,
        'action': 'update_communication_config',
        'details': {
          'settings': entries,
          'timestamp': now,
        },
      });
    } catch (_) {
      // Best-effort audit
    }
  }
}
