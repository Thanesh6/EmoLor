import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'supabase_service.dart';

/// Service for handling authentication operations
class AuthService {
  final SupabaseClient _client = SupabaseService.client;

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign up with email and password.
  /// After auth signup, calls the create_profile RPC (SECURITY DEFINER)
  /// to insert the profile row — no trigger dependency.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? pinHash,
    String? accountType,
    String? phone,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name, 'role': role},
      emailRedirectTo: 'emolor://login-callback/',
    );

    // Supabase returns a user with empty identities when the email is
    // already registered and verified — detect this and block re-registration.
    if (response.user != null &&
        (response.user!.identities == null ||
            response.user!.identities!.isEmpty)) {
      throw const AuthException(
          'This email is already registered. Please log in instead.');
    }

    if (response.user != null) {
      await _client.rpc('create_profile', params: {
        'p_user_id': response.user!.id,
        'p_email': email,
        'p_full_name': name,
        'p_role': role,
        'p_phone_number': phone,
        'p_account_type': accountType,
        'p_parent_pin_hash': pinHash,
      });
    }

    return response;
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Get User Role (from profiles table)
  Future<String?> getUserRole() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('profiles')
          .select('role')
          .eq('user_id', user.id)
          .single();

      return response['role'] as String?;
    } catch (e) {
      debugPrint('Error fetching role: $e');
      return null;
    }
  }

  // Get User Profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('user_id', user.id)
          .single();
      return response;
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }

  /// Check if email already exists in profiles table.
  /// Only verified users will have profiles that persist, so this check
  /// catches most duplicates before even calling signUp.
  Future<bool> emailExists(String email) async {
    try {
      final result = await _client
          .from('profiles')
          .select('user_id')
          .eq('email', email)
          .maybeSingle();
      return result != null;
    } catch (e) {
      debugPrint('Error checking email existence: $e');
      return false;
    }
  }

  // Update User Profile
  Future<void> updateProfile(
      {String? name, String? phone, String? avatar}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('User not logged in');

    final updates = <String, dynamic>{};
    if (name != null) updates['full_name'] = name;
    if (phone != null) updates['phone_number'] = phone;
    if (avatar != null) updates['avatar_url'] = avatar;

    if (updates.isEmpty) return;

    await _client.from('profiles').update(updates).eq('user_id', user.id);
  }

  /// Update (or set) the caregiver's parent PIN hash
  Future<void> updatePinHash(String pinHash) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('User not logged in');

    await _client.from('profiles').update({
      'parent_pin_hash': pinHash,
    }).eq('user_id', user.id);
  }

  // Soft Delete User (Deactivate)
  // Sets is_active = false on the profile row instead of deleting it.
  Future<void> softDeleteUser() async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('User not logged in');

    await _client.from('profiles').update({
      'is_active': false,
    }).eq('user_id', user.id);

    await signOut();
  }

  /// Re-authenticate by signing in with current email + provided password.
  /// Throws on failure (wrong password).
  Future<void> verifyPassword(String password) async {
    final user = _client.auth.currentUser;
    if (user == null || user.email == null) {
      throw const AuthException('User not logged in');
    }
    await _client.auth.signInWithPassword(
      email: user.email!,
      password: password,
    );
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'emolor://update-password/',
    );
  }

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
