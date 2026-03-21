import 'package:flutter_riverpod/flutter_riverpod.dart'; // REQUIRED for AsyncNotifier, AsyncData, etc.
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/auth_service.dart';

/// Holds the Auth State: User object or null
/// Using AsyncNotifier to handle loading states
class AuthNotifier extends AsyncNotifier<User?> {
  final AuthService _authService = AuthService();

  @override
  Future<User?> build() async {
    // 1. Check current session on startup
    final session = Supabase.instance.client.auth.currentSession;

    // 2. Listen to Auth Changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        state = AsyncData(data.session?.user);
      } else if (event == AuthChangeEvent.signedOut) {
        state = const AsyncData(null);
      } else if (event == AuthChangeEvent.tokenRefreshed) {
        state = AsyncData(data.session?.user);
      }
    });

    return session?.user;
  }

  /// Sign In
  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    try {
      final response =
          await _authService.signIn(email: email, password: password);
      state = AsyncData(response.user);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Sign Up
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? pinHash,
    String? accountType,
    String? phone,
  }) async {
    state = const AsyncLoading();
    try {
      await _authService.signUp(
        email: email,
        password: password,
        name: name,
        role: role,
        pinHash: pinHash,
        accountType: accountType,
        phone: phone,
      );
      // Supabase session often updates automatically, but we can rely on stream
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Sign Out — clears auth session AND local cached data
  Future<void> signOut() async {
    state = const AsyncLoading();
    // Wipe local storage / cached user data
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // End Supabase session
    await _authService.signOut();
    state = const AsyncData(null);
  }

  /// Reset Password
  Future<void> recoverPassword(String email) async {
    await _authService.resetPassword(email);
  }

  /// Helper: Get Current User Role from DB
  Future<String?> getUserRole() async {
    final user = state.value;
    if (user == null) return null;
    return await _authService.getUserRole();
  }

  // Helper to get Profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    return _authService.getUserProfile();
  }

  /// Update user profile in DB
  Future<void> updateProfile(
      {String? name, String? phone, String? avatar}) async {
    await _authService.updateProfile(name: name, phone: phone, avatar: avatar);
  }

  /// Update (or set) the caregiver's parent PIN hash
  Future<void> updatePinHash(String pinHash) async {
    await _authService.updatePinHash(pinHash);
  }

  /// Verify password then deactivate account (soft delete) and sign out
  Future<void> deactivateAccount(String password) async {
    // Re-authenticate first — throws if password is wrong
    await _authService.verifyPassword(password);
    // Soft delete (mark is_active = false)
    // softDeleteUser also calls signOut internally
    state = const AsyncLoading();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _authService.softDeleteUser();
    state = const AsyncData(null);
  }
}

// Provider Definition
final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(() {
  return AuthNotifier();
});
