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

  /// Sign up with email and password
  /// Note: The 'profiles' table is automatically updated via a Database Trigger
  /// on the 'auth.users' table. We pass metadata for the trigger to pick up.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? pinHash, // SHA-256 hash of the PIN
    String? accountType,
    String? phone,
  }) async {
    // metadata to be passed to Trigger
    final Map<String, dynamic> metadata = {
      'full_name': name,
      'role': role,
    };

    if (phone != null && phone.isNotEmpty) {
      metadata['phone'] = phone;
    }

    if (accountType != null && accountType.isNotEmpty) {
      metadata['account_type'] = accountType;
    }

    if (role == 'caregiver' && pinHash != null) {
      metadata['parent_pin_hash'] = pinHash;
    }

    // Supabase Auth SignUp with Metadata
    // The DB Trigger will handle the insertion into 'profiles' table
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: metadata,
    );

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

  /// Check if email already exists (via Supabase auth metadata)
  /// Since profiles table has no email column, we check auth.users indirectly
  /// by attempting a lookup. If the profile with that user exists, email is taken.
  Future<bool> emailExists(String email) async {
    // We can't query profiles by email since there's no email column.
    // Instead, we rely on Supabase auth — if signUp fails with
    // "User already registered", the email exists.
    // For a pre-check, we return false and let Supabase handle the duplicate.
    // A more robust approach would be a Supabase Edge Function.
    return false;
  }

  // Update User Profile
  Future<void> updateProfile({String? name, String? phone}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('User not logged in');

    final updates = <String, dynamic>{};
    if (name != null) updates['full_name'] = name;
    if (phone != null) updates['phone_number'] = phone;

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
    await _client.auth.resetPasswordForEmail(email);
  }

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
