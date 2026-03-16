import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

/// UCD042 – Edit Client Notes
///
/// CRUD service for private clinical notes that a therapist attaches
/// to a specific child's record.
class ClientNotesService {
  final SupabaseClient _client = SupabaseService.client;

  /// Default note categories.
  static const List<String> categories = [
    'General',
    'Behavioral',
    'Milestone',
    'Session Summary',
    'Follow-up',
  ];

  // ── Read ───────────────────────────────────────────────────────────────

  /// All notes the current therapist has written for [childId],
  /// ordered newest-first.
  Future<List<ClientNote>> getNotes(String childId) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return [];

    try {
      final rows = await _client
          .from('client_notes')
          .select()
          .eq('child_id', childId)
          .eq('therapist_id', userId)
          .order('created_at', ascending: false) as List;

      return rows.map((r) => ClientNote.fromJson(r)).toList();
    } catch (e) {
      debugPrint('ClientNotesService.getNotes error: $e');
      return [];
    }
  }

  // ── Create ─────────────────────────────────────────────────────────────

  /// Creates a new clinical note for [childId].
  /// Throws if the content is blank.
  Future<ClientNote> createNote({
    required String childId,
    required String content,
    String category = 'General',
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw Exception('Note content cannot be empty.');
    }

    final row = await _client
        .from('client_notes')
        .insert({
          'therapist_id': userId,
          'child_id': childId,
          'content': trimmed,
          'category': category,
        })
        .select()
        .single();

    return ClientNote.fromJson(row);
  }

  // ── Update ─────────────────────────────────────────────────────────────

  /// Updates an existing note's content and/or category.
  Future<ClientNote> updateNote({
    required String noteId,
    required String content,
    String? category,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw Exception('Note content cannot be empty.');
    }

    final updates = <String, dynamic>{'content': trimmed};
    if (category != null) updates['category'] = category;

    final row = await _client
        .from('client_notes')
        .update(updates)
        .eq('id', noteId)
        .select()
        .single();

    return ClientNote.fromJson(row);
  }

  // ── Delete ─────────────────────────────────────────────────────────────

  Future<void> deleteNote(String noteId) async {
    await _client.from('client_notes').delete().eq('id', noteId);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Data class ──────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

@immutable
class ClientNote {
  final String id;
  final String therapistId;
  final String childId;
  final String content;
  final String category;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClientNote({
    required this.id,
    required this.therapistId,
    required this.childId,
    required this.content,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get wasEdited =>
      updatedAt.isAfter(createdAt.add(const Duration(seconds: 2)));

  factory ClientNote.fromJson(Map<String, dynamic> json) {
    return ClientNote(
      id: json['id'] as String,
      therapistId: json['therapist_id'] as String,
      childId: json['child_id'] as String,
      content: json['content'] as String,
      category: (json['category'] as String?) ?? 'General',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
