import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../models/reward_catalog_item.dart';

/// UCD027 – Service for managing the global reward library.
///
/// Handles CRUD against the `reward_library` table and icon upload/delete
/// in the `reward_icons` Supabase Storage bucket.
class RewardLibraryService {
  final SupabaseClient _client = SupabaseService.client;

  /// Storage bucket for reward icon assets.
  static const String _bucket = 'reward_icons';

  /// DB table.
  static const String _table = 'reward_library';

  // ── Allowed formats & size ────────────────────────────────────────────

  static const allowedMimeTypes = {
    'image/png',
    'image/jpeg',
    'image/jpg',
    'image/svg+xml',
  };

  static const allowedExtensions = ['png', 'jpg', 'jpeg', 'svg'];

  /// Maximum icon file size – 5 MB.
  static const int maxFileSizeBytes = 5 * 1024 * 1024;

  // ── Validation ────────────────────────────────────────────────────────

  /// Returns an error message if invalid, or `null` if OK.
  static String? validateIconFile({
    required String fileName,
    required int sizeBytes,
  }) {
    final ext = fileName.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(ext)) {
      return 'Invalid format. Please upload PNG, JPG, or SVG only.';
    }
    if (sizeBytes > maxFileSizeBytes) {
      return 'File too large. Maximum size is 5 MB.';
    }
    return null;
  }

  static String? _extToMime(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'svg':
        return 'image/svg+xml';
      default:
        return null;
    }
  }

  // ── Fetch ─────────────────────────────────────────────────────────────

  /// Fetch all rewards from the global catalog, optionally filtered.
  Future<List<RewardCatalogItem>> getRewards({
    RewardCategory? category,
  }) async {
    try {
      var query = _client.from(_table).select();
      if (category != null) {
        query = query.eq('category', category.value);
      }
      final rows = await query.order('created_at', ascending: false);
      return (rows as List)
          .map((r) => RewardCatalogItem.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('RewardLibraryService.getRewards error: $e');
      rethrow;
    }
  }

  /// Fetch a single reward by id.
  Future<RewardCatalogItem> getReward(String id) async {
    final row = await _client.from(_table).select().eq('id', id).single();
    return RewardCatalogItem.fromJson(row);
  }

  // ── Create ────────────────────────────────────────────────────────────

  /// Creates a new reward in the global catalog.
  ///
  /// Optionally uploads an icon file.
  Future<RewardCatalogItem> createReward({
    required String name,
    String? description,
    required RewardCategory category,
    required int pointCost,
    String? iconFileName,
    Uint8List? iconFileBytes,
  }) async {
    String? iconUrl;
    String? storagePath;

    // 1. Upload icon if provided
    if (iconFileName != null && iconFileBytes != null) {
      final error = validateIconFile(
          fileName: iconFileName, sizeBytes: iconFileBytes.length);
      if (error != null) throw Exception(error);

      final ext = iconFileName.split('.').last.toLowerCase();
      final mime = _extToMime(ext) ?? 'application/octet-stream';
      storagePath =
          '${category.value}/${DateTime.now().millisecondsSinceEpoch}_$iconFileName';

      await _client.storage.from(_bucket).uploadBinary(
            storagePath,
            iconFileBytes,
            fileOptions: FileOptions(contentType: mime),
          );

      iconUrl = _client.storage.from(_bucket).getPublicUrl(storagePath);
    }

    // 2. Insert DB row
    final row = await _client
        .from(_table)
        .insert({
          'name': name,
          'description': description,
          'category': category.value,
          'point_cost': pointCost,
          'icon_url': iconUrl,
          'icon_file_name': iconFileName,
          'icon_file_path': storagePath,
          'is_active': true,
        })
        .select()
        .single();

    // 3. Audit
    await _auditLog('create_reward', row['id'] as String, {
      'name': name,
      'category': category.value,
      'point_cost': pointCost,
    });

    return RewardCatalogItem.fromJson(row);
  }

  // ── Update ────────────────────────────────────────────────────────────

  /// Updates an existing reward's metadata and optionally replaces the icon.
  Future<RewardCatalogItem> updateReward({
    required String rewardId,
    required String name,
    String? description,
    required RewardCategory category,
    required int pointCost,
    String? newIconFileName,
    Uint8List? newIconFileBytes,
  }) async {
    try {
      String? iconUrl;
      String? storagePath;
      String? iconFileName;

      // 1. Upload new icon if provided
      if (newIconFileName != null && newIconFileBytes != null) {
        final error = validateIconFile(
            fileName: newIconFileName, sizeBytes: newIconFileBytes.length);
        if (error != null) throw Exception(error);

        // Remove old icon first
        final existing = await getReward(rewardId);
        if (existing.iconFilePath != null &&
            existing.iconFilePath!.isNotEmpty) {
          try {
            await _client.storage
                .from(_bucket)
                .remove([existing.iconFilePath!]);
          } catch (_) {
            // Ignore removal errors
          }
        }

        final ext = newIconFileName.split('.').last.toLowerCase();
        final mime = _extToMime(ext) ?? 'application/octet-stream';
        storagePath =
            '${category.value}/${DateTime.now().millisecondsSinceEpoch}_$newIconFileName';

        await _client.storage.from(_bucket).uploadBinary(
              storagePath,
              newIconFileBytes,
              fileOptions: FileOptions(contentType: mime),
            );

        iconUrl = _client.storage.from(_bucket).getPublicUrl(storagePath);
        iconFileName = newIconFileName;
      }

      // 2. Build updates map
      final updates = <String, dynamic>{
        'name': name,
        'description': description,
        'category': category.value,
        'point_cost': pointCost,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (iconUrl != null) {
        updates['icon_url'] = iconUrl;
        updates['icon_file_name'] = iconFileName;
        updates['icon_file_path'] = storagePath;
      }

      // 3. Update DB
      final row = await _client
          .from(_table)
          .update(updates)
          .eq('id', rewardId)
          .select()
          .single();

      // 4. Audit
      await _auditLog('edit_reward', rewardId, updates);

      return RewardCatalogItem.fromJson(row);
    } catch (e) {
      debugPrint('RewardLibraryService.updateReward error: $e');
      rethrow;
    }
  }

  // ── Archive ───────────────────────────────────────────────────────────

  /// Archives a reward (sets is_active = false) instead of deleting it.
  Future<void> archiveReward(String rewardId) async {
    await _client.from(_table).update({
      'is_active': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', rewardId);

    await _auditLog('archive_reward', rewardId, {});
  }

  // ── Delete (with integrity check) ────────────────────────────────────

  /// Checks if any child has unlocked this reward.
  ///
  /// Returns `true` if safe to delete (no children own it).
  Future<bool> canDelete(String rewardId) async {
    try {
      // Check child_reward_inventory (UCD026)
      final rows = await _client
          .from('child_reward_inventory')
          .select('id')
          .eq('reward_id', rewardId)
          .limit(1);
      if ((rows as List).isNotEmpty) return false;

      // Also check legacy rewards table
      final legacyRows = await _client
          .from('rewards')
          .select('id')
          .eq('metadata->>reward_library_id', rewardId)
          .limit(1);
      if ((legacyRows as List).isNotEmpty) return false;

      return true;
    } catch (e) {
      debugPrint('RewardLibraryService.canDelete error: $e');
      // Fail-safe: don't allow deletion if check fails
      return false;
    }
  }

  /// Permanently deletes a reward.
  ///
  /// Call [canDelete] first. If the reward is owned by users, use
  /// [archiveReward] instead.
  Future<void> deleteReward(String rewardId) async {
    try {
      // 1. Fetch to get storage path
      final row =
          await _client.from(_table).select().eq('id', rewardId).single();

      // 2. Remove icon from storage
      final storagePath = row['icon_file_path'] as String?;
      if (storagePath != null && storagePath.isNotEmpty) {
        await _client.storage.from(_bucket).remove([storagePath]);
      }

      // 3. Delete DB row
      await _client.from(_table).delete().eq('id', rewardId);

      // 4. Audit
      await _auditLog('delete_reward', rewardId, {
        'name': row['name'],
      });
    } catch (e) {
      debugPrint('RewardLibraryService.deleteReward error: $e');
      rethrow;
    }
  }

  // ── Audit helper ──────────────────────────────────────────────────────

  Future<void> _auditLog(
    String action,
    String targetId,
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
          'reward_id': targetId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      });
    } catch (e) {
      debugPrint('RewardLibraryService._auditLog error: $e');
    }
  }
}
