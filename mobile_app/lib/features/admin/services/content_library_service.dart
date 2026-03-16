import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../models/content_asset.dart';

/// UCD019 – Service for managing global content assets.
///
/// Handles CRUD against the `content_assets` table and file upload/delete
/// in the `content_assets` Supabase Storage bucket.
class ContentLibraryService {
  final SupabaseClient _client = SupabaseService.client;

  /// The Supabase Storage bucket used for content assets.
  static const String _bucket = 'content_assets';

  // ── Allowed formats & size ────────────────────────────────────────────

  /// Allowed MIME types (JPG, PNG, MP3 per spec).
  static const allowedMimeTypes = {
    'image/jpeg',
    'image/jpg',
    'image/png',
    'audio/mpeg', // mp3
    'audio/mp3',
  };

  /// Maximum file size – 10 MB.
  static const int maxFileSizeBytes = 10 * 1024 * 1024;

  // ── Validation ────────────────────────────────────────────────────────

  /// Returns an error message if the file is invalid, or `null` if OK.
  static String? validateFile({
    required String fileName,
    required int sizeBytes,
  }) {
    final ext = fileName.split('.').last.toLowerCase();
    final mime = _extToMime(ext);
    if (mime == null || !allowedMimeTypes.contains(mime)) {
      return 'Invalid format. Please upload PNG, JPG, or MP3 only.';
    }
    if (sizeBytes > maxFileSizeBytes) {
      return 'File too large. Maximum size is 10 MB.';
    }
    return null; // valid
  }

  /// Map common extensions to MIME types.
  static String? _extToMime(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'mp3':
        return 'audio/mpeg';
      default:
        return null;
    }
  }

  // ── Fetch ─────────────────────────────────────────────────────────────

  /// Fetch all assets, optionally filtered by [category].
  Future<List<ContentAsset>> getAssets({AssetCategory? category}) async {
    try {
      var query = _client.from('content_assets').select();
      if (category != null) {
        query = query.eq('category', category.value);
      }
      final rows = await query.order('created_at', ascending: false);
      return (rows as List)
          .map((r) => ContentAsset.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('ContentLibraryService.getAssets error: $e');
      rethrow;
    }
  }

  // ── Upload ────────────────────────────────────────────────────────────

  /// Uploads a file to Supabase Storage and creates a database record.
  ///
  /// Returns the created [ContentAsset].
  ///
  /// Throws on validation failure, storage error, or DB error.
  Future<ContentAsset> uploadAsset({
    required String title,
    String? description,
    required AssetCategory category,
    String? tag,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    // 1. Validate
    final error = validateFile(fileName: fileName, sizeBytes: fileBytes.length);
    if (error != null) throw Exception(error);

    final ext = fileName.split('.').last.toLowerCase();
    final mime = _extToMime(ext) ?? 'application/octet-stream';

    // 2. Build a unique storage path
    final storagePath =
        '${category.value}/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    // 3. Upload to Storage
    await _client.storage.from(_bucket).uploadBinary(
          storagePath,
          fileBytes,
          fileOptions: FileOptions(contentType: mime),
        );

    // 4. Get public URL
    final fileUrl = _client.storage.from(_bucket).getPublicUrl(storagePath);

    // 5. Insert DB record
    final row = await _client
        .from('content_assets')
        .insert({
          'title': title,
          'description': description,
          'category': category.value,
          'file_url': fileUrl,
          'file_name': fileName,
          'file_path': storagePath,
          'mime_type': mime,
          'file_size_bytes': fileBytes.length,
          'tag': tag,
          'is_active': true,
        })
        .select()
        .single();

    // 6. Audit log
    await _auditLog('upload_asset', row['id'] as String, {
      'title': title,
      'category': category.value,
      'file_name': fileName,
    });

    return ContentAsset.fromJson(row);
  }

  // ── Update metadata ───────────────────────────────────────────────────

  /// Updates editable metadata (title, description, tag, category).
  Future<ContentAsset> updateAsset({
    required String assetId,
    required String title,
    String? description,
    String? tag,
    AssetCategory? category,
  }) async {
    try {
      final updates = <String, dynamic>{
        'title': title,
        'description': description,
        'tag': tag,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (category != null) {
        updates['category'] = category.value;
      }

      final row = await _client
          .from('content_assets')
          .update(updates)
          .eq('id', assetId)
          .select()
          .single();

      await _auditLog('edit_asset', assetId, updates);

      return ContentAsset.fromJson(row);
    } catch (e) {
      debugPrint('ContentLibraryService.updateAsset error: $e');
      rethrow;
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────

  /// Checks whether the asset is currently referenced by a child's active
  /// profile (e.g. as an avatar or reward badge). Returns `true` if safe.
  Future<bool> canDelete(String assetId) async {
    try {
      // Check if used in rewards table
      final rewardRows = await _client
          .from('rewards')
          .select('id')
          .eq('badge_asset_id', assetId)
          .limit(1);
      if ((rewardRows as List).isNotEmpty) return false;

      // Check if used as a child avatar
      final asset = await _client
          .from('content_assets')
          .select('file_url')
          .eq('id', assetId)
          .single();
      final url = asset['file_url'] as String?;
      if (url != null) {
        final avatarRows = await _client
            .from('profiles')
            .select('profile_id')
            .eq('avatar_url', url)
            .limit(1);
        if ((avatarRows as List).isNotEmpty) return false;
      }

      return true;
    } catch (e) {
      debugPrint('ContentLibraryService.canDelete check error: $e');
      // If the check fails, allow deletion (fail-open for admin).
      return true;
    }
  }

  /// Deletes an asset's storage file and database record.
  ///
  /// Call [canDelete] first to verify the asset isn't in use.
  Future<void> deleteAsset(String assetId) async {
    try {
      // 1. Fetch the row so we know the storage path.
      final row = await _client
          .from('content_assets')
          .select()
          .eq('id', assetId)
          .single();

      final storagePath = row['file_path'] as String?;

      // 2. Remove from storage.
      if (storagePath != null && storagePath.isNotEmpty) {
        await _client.storage.from(_bucket).remove([storagePath]);
      }

      // 3. Delete DB row.
      await _client.from('content_assets').delete().eq('id', assetId);

      // 4. Audit
      await _auditLog('delete_asset', assetId, {
        'title': row['title'],
        'file_name': row['file_name'],
      });
    } catch (e) {
      debugPrint('ContentLibraryService.deleteAsset error: $e');
      rethrow;
    }
  }

  // ── Audit helper ──────────────────────────────────────────────────────

  Future<void> _auditLog(
    String action,
    String targetAssetId,
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
          'asset_id': targetAssetId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      });
    } catch (e) {
      debugPrint('ContentLibraryService._auditLog error: $e');
    }
  }
}
