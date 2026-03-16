import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/models/activity_model.dart';

/// UCD020 – Service for managing activity instruction content.
///
/// Handles reading / writing the `instruction_text` and
/// `instruction_image_url` columns on the `activities` table, plus
/// uploading demo images to the `activity_content` storage bucket.
class ActivityInstructionsService {
  final SupabaseClient _client = SupabaseService.client;

  /// Storage bucket for activity instruction images.
  static const String _bucket = 'activity_content';

  // ── Fetch ─────────────────────────────────────────────────────────────

  /// Returns all activities (active or not) for the admin list.
  Future<List<ActivityModel>> getAllActivities() async {
    try {
      final rows = await _client
          .from('activities')
          .select()
          .order('title', ascending: true);
      return (rows as List)
          .map((r) => ActivityModel.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('ActivityInstructionsService.getAllActivities error: $e');
      rethrow;
    }
  }

  /// Fetches the raw row for a single activity (includes instruction
  /// columns that may not be on the Dart model yet).
  Future<Map<String, dynamic>> getActivityRaw(String activityId) async {
    final row =
        await _client.from('activities').select().eq('id', activityId).single();
    return row;
  }

  // ── Save instructions ─────────────────────────────────────────────────

  /// Persists the instruction text and optional demo-image URL.
  ///
  /// Validates that [instructionText] is not empty (UCD020 alt-flow).
  Future<void> saveInstructions({
    required String activityId,
    required String instructionText,
    String? instructionImageUrl,
  }) async {
    if (instructionText.trim().isEmpty) {
      throw Exception('Instruction text cannot be empty.');
    }

    await _client.from('activities').update({
      'instruction_text': instructionText.trim(),
      'instruction_image_url': instructionImageUrl,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', activityId);

    // Audit
    await _auditLog('update_instructions', activityId, {
      'instruction_text_length': instructionText.trim().length,
      'has_image': instructionImageUrl != null,
    });
  }

  // ── Upload demo image ─────────────────────────────────────────────────

  /// Uploads a visual demonstration image and returns its public URL.
  ///
  /// Accepts PNG and JPG only, max 5 MB.
  Future<String> uploadDemoImage({
    required String activityId,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    // Validate format
    final ext = fileName.split('.').last.toLowerCase();
    if (!{'jpg', 'jpeg', 'png'}.contains(ext)) {
      throw Exception('Invalid image format. Please upload PNG or JPG only.');
    }
    // Validate size
    if (fileBytes.length > 5 * 1024 * 1024) {
      throw Exception('Image too large. Maximum size is 5 MB.');
    }

    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    final storagePath =
        'instructions/${activityId}_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.storage.from(_bucket).uploadBinary(
          storagePath,
          fileBytes,
          fileOptions: FileOptions(contentType: mime),
        );

    return _client.storage.from(_bucket).getPublicUrl(storagePath);
  }

  /// Removes a previously-uploaded demo image from storage.
  Future<void> removeDemoImage(String imageUrl) async {
    try {
      // Extract the storage path from the public URL.
      final uri = Uri.parse(imageUrl);
      final segments = uri.pathSegments;
      // Path is usually: /storage/v1/object/public/<bucket>/<path...>
      final bucketIdx = segments.indexOf(_bucket);
      if (bucketIdx >= 0 && bucketIdx < segments.length - 1) {
        final path = segments.sublist(bucketIdx + 1).join('/');
        await _client.storage.from(_bucket).remove([path]);
      }
    } catch (e) {
      debugPrint('ActivityInstructionsService.removeDemoImage error: $e');
      // Non-critical — log and continue.
    }
  }

  // ── Audit ─────────────────────────────────────────────────────────────

  /// UCD021 – Available animation styles for completion feedback.
  static const List<String> animationStyles = [
    'confetti',
    'star_burst',
    'balloons',
  ];

  /// UCD021 – Available sound effects for completion feedback.
  static const List<String> soundEffects = [
    'applause',
    'chime',
    'fanfare',
  ];

  /// UCD021 – Persists the per-activity completion feedback configuration.
  ///
  /// At least one of [feedbackText] or [feedbackAnimation] must be provided
  /// (alt-flow: "Please define at least one feedback element.").
  Future<void> saveFeedbackConfig({
    required String activityId,
    String? feedbackText,
    String? feedbackAnimation,
    String? feedbackSound,
  }) async {
    final hasText = feedbackText != null && feedbackText.trim().isNotEmpty;
    final hasVisual =
        feedbackAnimation != null && feedbackAnimation.trim().isNotEmpty;

    if (!hasText && !hasVisual) {
      throw Exception('Please define at least one feedback element.');
    }

    await _client.from('activities').update({
      'feedback_text': hasText ? feedbackText.trim() : null,
      'feedback_animation': hasVisual ? feedbackAnimation : null,
      'feedback_sound': (feedbackSound != null && feedbackSound.isNotEmpty)
          ? feedbackSound
          : null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', activityId);

    await _auditLog('update_feedback_config', activityId, {
      'feedback_text_length': hasText ? feedbackText.trim().length : 0,
      'feedback_animation': feedbackAnimation,
      'feedback_sound': feedbackSound,
    });
  }

  // ── Audit (internal) ──────────────────────────────────────────────────

  Future<void> _auditLog(
    String action,
    String activityId,
    Map<String, dynamic> details,
  ) async {
    final adminId = SupabaseService.currentUserId;
    if (adminId == null) return;
    try {
      await _client.from('admin_audit_log').insert({
        'admin_user_id': adminId,
        'action': action,
        'target_user_id': null,
        'details': {
          ...details,
          'activity_id': activityId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      });
    } catch (e) {
      debugPrint('ActivityInstructionsService._auditLog error: $e');
    }
  }
}
