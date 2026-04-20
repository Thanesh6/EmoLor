import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../models/child_profile.dart';

/// Service for managing child profiles.
/// Real schema: children are rows in `profiles` table linked via `family_links`.
/// `family_links` columns: caregiver_id, child_id (both FK → profiles.user_id)
class ChildProfileService {
  final SupabaseClient _client = SupabaseService.client;

  /// Get all child profiles linked to the current caregiver via RPC
  Future<List<ChildProfile>> getMyChildProfiles() async {
    final userId = SupabaseService.currentUserId;

    if (userId == null) {
      return [];
    }

    try {
      final response = await _client.rpc('get_child_profiles', params: {
        'p_caregiver_id': userId,
      });

      return (response as List)
          .map((json) => ChildProfile.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Fallback: try direct query (may fail with RLS)
      final links = await _client
          .from('family_links')
          .select('child_id')
          .eq('caregiver_id', userId);

      final childIds =
          (links as List).map((l) => l['child_id'] as String).toList();
      if (childIds.isEmpty) return [];

      final profiles = await _client
          .from('profiles')
          .select()
          .inFilter('user_id', childIds)
          .order('full_name');

      return (profiles as List)
          .map((json) => ChildProfile.fromJson(json))
          .toList();
    }
  }

  /// Get a specific child profile by profile_id
  Future<ChildProfile?> getChildProfile(String profileId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('profile_id', profileId)
        .maybeSingle();

    if (response == null) return null;
    return ChildProfile.fromJson(response);
  }

  /// Create a new child profile and link to current caregiver via RPC.
  /// Uses SECURITY DEFINER function to bypass RLS and handle ENUM cast.
  Future<ChildProfile> createChildProfile({
    required String name,
    DateTime? dateOfBirth,
    String? avatarUrl,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _client.rpc('create_child_profile', params: {
      'p_caregiver_id': userId,
      'p_full_name': name,
      'p_date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
      'p_avatar_url': avatarUrl,
    });

    return ChildProfile.fromJson(response as Map<String, dynamic>);
  }

  /// Update a child profile
  Future<ChildProfile> updateChildProfile({
    required String profileId,
    String? name,
    DateTime? dateOfBirth,
    String? avatarUrl,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['full_name'] = name;
    if (dateOfBirth != null) {
      data['date_of_birth'] = dateOfBirth.toIso8601String();
    }
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;

    final response = await _client
        .from('profiles')
        .update(data)
        .eq('profile_id', profileId)
        .select()
        .single();

    return ChildProfile.fromJson(response);
  }

  /// Delete a child profile (remove family_link — profile row can stay).
  /// Uses SECURITY DEFINER RPC to bypass RLS restrictions.
  Future<void> deleteChildProfile(String childUserId) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final result = await _client.rpc('delete_child_profile', params: {
      'p_caregiver_id': userId,
      'p_child_user_id': childUserId,
    });

    final deleted = (result is int) ? result : int.tryParse(result.toString()) ?? 0;
    if (deleted == 0) {
      throw Exception('No profile was deleted — link not found');
    }
  }

  /// Get child profiles linked to a therapist via therapist_client_link
  Future<List<ChildProfile>> getTherapistChildProfiles() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final links = await _client
        .from('therapist_client_link')
        .select('client_id')
        .eq('therapist_id', userId);

    final clientIds =
        (links as List).map((l) => l['client_id'] as String).toList();
    if (clientIds.isEmpty) return [];

    final profiles = await _client
        .from('profiles')
        .select()
        .inFilter('user_id', clientIds)
        .order('full_name');

    return (profiles as List)
        .map((json) => ChildProfile.fromJson(json))
        .toList();
  }

  /// Get all child profiles (admin only — profiles with role = 'child')
  Future<List<ChildProfile>> getAllChildProfiles() async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('role', 'child')
        .order('full_name');

    return (response as List)
        .map((json) => ChildProfile.fromJson(json))
        .toList();
  }
}
