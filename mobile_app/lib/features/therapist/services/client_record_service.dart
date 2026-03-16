import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/models/scheduled_session.dart';

/// UCD039 – View Client Record
///
/// Service for the therapist's "My Clients" list and a child's
/// comprehensive Client Record (bio-data, sensory profile, clinical
/// history).
class ClientRecordService {
  final SupabaseClient _client = SupabaseService.client;

  // ── My Clients list ───────────────────────────────────────────────────

  /// Returns all children linked to the current therapist via
  /// `therapist_client_link` → `child_profiles`.
  /// Each entry also carries the caregiver display name and contact info.
  Future<List<ClientSummary>> getMyClients() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    // 1. Linked caregiver IDs
    final links = await _client
        .from('therapist_client_link')
        .select('client_id')
        .eq('therapist_id', userId) as List;

    if (links.isEmpty) return [];

    final caregiverIds = links.map((l) => l['client_id'] as String).toList();

    // 2. Caregiver profiles
    final caregiverRows = await _client
        .from('profiles')
        .select('user_id, full_name, phone_number, email')
        .inFilter('user_id', caregiverIds) as List;

    final caregiverMap = <String, Map<String, dynamic>>{};
    for (final c in caregiverRows) {
      caregiverMap[c['user_id'] as String] = c;
    }

    // 3. Children
    final children = await _client
        .from('child_profiles')
        .select()
        .inFilter('caregiver_id', caregiverIds)
        .eq('is_active', true)
        .order('full_name') as List;

    return children.map((ch) {
      final cgId = ch['caregiver_id'] as String;
      final cg = caregiverMap[cgId];
      return ClientSummary(
        childId: ch['id'] as String,
        childName: (ch['full_name'] as String?) ?? 'Child',
        age: ch['age'] as int?,
        avatarUrl: ch['avatar_url'] as String?,
        caregiverId: cgId,
        caregiverName: (cg?['full_name'] as String?) ?? 'Caregiver',
        caregiverPhone: cg?['phone_number'] as String?,
        caregiverEmail: cg?['email'] as String?,
      );
    }).toList();
  }

  // ── Linkage validation ────────────────────────────────────────────────

  /// Returns `true` when the current therapist is still linked to the
  /// caregiver that owns [childId].
  Future<bool> isLinkedToChild(String childId) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return false;

    try {
      // Get the child's caregiver
      final child = await _client
          .from('child_profiles')
          .select('caregiver_id')
          .eq('id', childId)
          .maybeSingle();

      if (child == null) return false;

      final caregiverId = child['caregiver_id'] as String;

      // Verify therapist↔caregiver link
      final link = await _client
          .from('therapist_client_link')
          .select('id')
          .eq('therapist_id', userId)
          .eq('client_id', caregiverId)
          .maybeSingle();

      return link != null;
    } catch (e) {
      debugPrint('ClientRecordService.isLinkedToChild error: $e');
      return false;
    }
  }

  // ── Full client record ────────────────────────────────────────────────

  /// Bio-data: child profile + caregiver contact.
  Future<ClientBioData?> getBioData(String childId) async {
    try {
      final child = await _client
          .from('child_profiles')
          .select()
          .eq('id', childId)
          .maybeSingle();

      if (child == null) return null;

      final cgId = child['caregiver_id'] as String;
      final caregiver = await _client
          .from('profiles')
          .select('user_id, full_name, phone_number, email')
          .eq('user_id', cgId)
          .maybeSingle();

      return ClientBioData(
        childId: child['id'] as String,
        childName: (child['full_name'] as String?) ?? 'Child',
        age: child['age'] as int?,
        dateOfBirth: child['date_of_birth'] != null
            ? DateTime.tryParse(child['date_of_birth'] as String)
            : null,
        avatarUrl: child['avatar_url'] as String?,
        preferences: child['preferences'] as Map<String, dynamic>? ?? {},
        caregiverId: cgId,
        caregiverName: (caregiver?['full_name'] as String?) ?? 'Caregiver',
        caregiverPhone: caregiver?['phone_number'] as String?,
        caregiverEmail: caregiver?['email'] as String?,
      );
    } catch (e) {
      debugPrint('ClientRecordService.getBioData error: $e');
      return null;
    }
  }

  /// Sensory profile: emotion–colour mappings for the child.
  Future<List<EmotionColourEntry>> getEmotionColours(String childId) async {
    try {
      final rows = await _client
          .from('emotion_colors')
          .select()
          .eq('child_profile_id', childId)
          .order('emotion_name') as List;

      return rows
          .map((r) => EmotionColourEntry(
                id: r['id'] as String,
                emotionName: r['emotion_name'] as String,
                colorHex: r['color_hex'] as String,
                icon: r['icon'] as String?,
              ))
          .toList();
    } catch (e) {
      debugPrint('ClientRecordService.getEmotionColours error: $e');
      return [];
    }
  }

  /// Recent emotion journal entries for the child.
  Future<List<EmotionJournalEntry>> getEmotionEntries(
    String childId, {
    int limit = 30,
  }) async {
    try {
      final rows = await _client
          .from('emotion_entries')
          .select()
          .eq('child_profile_id', childId)
          .order('timestamp', ascending: false)
          .limit(limit) as List;

      return rows
          .map((r) => EmotionJournalEntry(
                id: r['id'] as String,
                emotionName: r['emotion_name'] as String,
                intensity: r['intensity'] as int? ?? 3,
                notes: r['notes'] as String?,
                trigger: r['trigger'] as String?,
                timestamp: DateTime.parse(r['timestamp'] as String),
              ))
          .toList();
    } catch (e) {
      debugPrint('ClientRecordService.getEmotionEntries error: $e');
      return [];
    }
  }

  /// Clinical history — past sessions for this child with the current
  /// therapist (or all therapists).
  Future<List<ScheduledSession>> getSessionHistory(String childId) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return [];

    try {
      final rows = await _client
          .from('sessions')
          .select()
          .eq('child_profile_id', childId)
          .eq('therapist_id', userId)
          .order('session_date', ascending: false) as List;

      return rows.map((r) => ScheduledSession.fromJson(r)).toList();
    } catch (e) {
      debugPrint('ClientRecordService.getSessionHistory error: $e');
      return [];
    }
  }

  /// Activity progress logs for the child.
  Future<List<ActivityProgressEntry>> getActivityProgress(
      String childId) async {
    try {
      final rows = await _client
          .from('activity_progress')
          .select('*, activities(title, activity_type, difficulty)')
          .eq('child_profile_id', childId)
          .order('updated_at', ascending: false) as List;

      return rows.map((r) {
        final activity = r['activities'] as Map<String, dynamic>?;
        return ActivityProgressEntry(
          id: r['id'] as String,
          activityTitle: (activity?['title'] as String?) ?? 'Activity',
          activityType: (activity?['activity_type'] as String?) ?? '',
          difficulty: (activity?['difficulty'] as String?) ?? '',
          status: r['status'] as String? ?? 'started',
          score: r['score'] as int?,
          completionPct: r['completion_percentage'] as int? ?? 0,
          timeSpentSecs: r['time_spent_seconds'] as int? ?? 0,
          starsEarned: r['stars_earned'] as int? ?? 0,
          completedAt: r['completed_at'] != null
              ? DateTime.tryParse(r['completed_at'] as String)
              : null,
          updatedAt: DateTime.parse(r['updated_at'] as String),
        );
      }).toList();
    } catch (e) {
      debugPrint('ClientRecordService.getActivityProgress error: $e');
      return [];
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Data classes ─────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

/// Lightweight summary for the My Clients list.
@immutable
class ClientSummary {
  final String childId;
  final String childName;
  final int? age;
  final String? avatarUrl;
  final String caregiverId;
  final String caregiverName;
  final String? caregiverPhone;
  final String? caregiverEmail;

  const ClientSummary({
    required this.childId,
    required this.childName,
    this.age,
    this.avatarUrl,
    required this.caregiverId,
    required this.caregiverName,
    this.caregiverPhone,
    this.caregiverEmail,
  });
}

/// Full bio-data for the Client Record header.
@immutable
class ClientBioData {
  final String childId;
  final String childName;
  final int? age;
  final DateTime? dateOfBirth;
  final String? avatarUrl;
  final Map<String, dynamic> preferences;
  final String caregiverId;
  final String caregiverName;
  final String? caregiverPhone;
  final String? caregiverEmail;

  const ClientBioData({
    required this.childId,
    required this.childName,
    this.age,
    this.dateOfBirth,
    this.avatarUrl,
    this.preferences = const {},
    required this.caregiverId,
    required this.caregiverName,
    this.caregiverPhone,
    this.caregiverEmail,
  });
}

/// A single emotion–colour mapping row.
@immutable
class EmotionColourEntry {
  final String id;
  final String emotionName;
  final String colorHex;
  final String? icon;

  const EmotionColourEntry({
    required this.id,
    required this.emotionName,
    required this.colorHex,
    this.icon,
  });
}

/// A single emotion journal entry.
@immutable
class EmotionJournalEntry {
  final String id;
  final String emotionName;
  final int intensity;
  final String? notes;
  final String? trigger;
  final DateTime timestamp;

  const EmotionJournalEntry({
    required this.id,
    required this.emotionName,
    required this.intensity,
    this.notes,
    this.trigger,
    required this.timestamp,
  });
}

/// A single row from activity_progress + joined activity data.
@immutable
class ActivityProgressEntry {
  final String id;
  final String activityTitle;
  final String activityType;
  final String difficulty;
  final String status;
  final int? score;
  final int completionPct;
  final int timeSpentSecs;
  final int starsEarned;
  final DateTime? completedAt;
  final DateTime updatedAt;

  const ActivityProgressEntry({
    required this.id,
    required this.activityTitle,
    required this.activityType,
    required this.difficulty,
    required this.status,
    this.score,
    required this.completionPct,
    required this.timeSpentSecs,
    required this.starsEarned,
    this.completedAt,
    required this.updatedAt,
  });

  String get formattedTime {
    final mins = timeSpentSecs ~/ 60;
    final secs = timeSpentSecs % 60;
    return mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
  }
}
