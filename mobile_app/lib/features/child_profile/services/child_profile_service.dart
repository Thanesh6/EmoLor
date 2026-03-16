import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../models/child_profile.dart';

/// Service for managing child profiles.
/// Real schema: children are rows in `profiles` table linked via `family_links`.
/// `family_links` columns: caregiver_id, child_id (both FK → profiles.user_id)
class ChildProfileService {
  final SupabaseClient _client = SupabaseService.client;

  /// Get all child profiles linked to the current caregiver via family_links
  Future<List<ChildProfile>> getMyChildProfiles() async {
    final userId = SupabaseService.currentUserId;

    // DEV MODE: If no user is logged in, return dummy profiles
    if (userId == null) {
      return [
        ChildProfile(
          profileId: 'dummy-1',
          userId: 'dummy-child-1',
          name: 'Emma',
          dateOfBirth: DateTime(2018, 5, 15),
          avatarUrl: null,
        ),
        ChildProfile(
          profileId: 'dummy-2',
          userId: 'dummy-child-2',
          name: 'Noah',
          dateOfBirth: DateTime(2016, 3, 22),
          avatarUrl: null,
        ),
      ];
    }

    // Step 1: Get linked child user_ids from family_links
    final links = await _client
        .from('family_links')
        .select('child_id')
        .eq('caregiver_id', userId);

    final childIds =
        (links as List).map((l) => l['child_id'] as String).toList();
    if (childIds.isEmpty) return [];

    // Step 2: Get profiles for those children
    final profiles = await _client
        .from('profiles')
        .select()
        .inFilter('user_id', childIds)
        .order('full_name');

    return (profiles as List)
        .map((json) => ChildProfile.fromJson(json))
        .toList();
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

  /// Create a new child profile and link to current caregiver.
  /// NOTE: This creates a new row in `profiles` and a `family_links` entry.
  /// The child needs a user_id (auth.users entry) — in practice this may be
  /// created via a Supabase Edge Function or trigger.
  Future<ChildProfile> createChildProfile({
    required String name,
    DateTime? dateOfBirth,
    String? avatarUrl,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    // Insert profile for the child
    // NOTE: user_id must be set — this assumes a child auth account exists.
    // A real implementation may need an Edge Function to create the auth user.
    final data = {
      'full_name': name,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'avatar_url': avatarUrl,
      'role': 'child',
    };

    final response =
        await _client.from('profiles').insert(data).select().single();

    final childProfile = ChildProfile.fromJson(response);

    // Link child to caregiver
    await _client.from('family_links').insert({
      'caregiver_id': userId,
      'child_id': childProfile.userId,
    });

    return childProfile;
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

  /// Delete a child profile (remove family_link — profile row can stay)
  Future<void> deleteChildProfile(String childUserId) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from('family_links')
        .delete()
        .eq('caregiver_id', userId)
        .eq('child_id', childUserId);
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
