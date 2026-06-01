import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/auth_service.dart';

class AuthNotifier extends AsyncNotifier<User?> {
  final AuthService _authService = AuthService();

  @override
  Future<User?> build() async {
    final session = Supabase.instance.client.auth.currentSession;

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;

      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        state = AsyncData(data.session?.user);
      }

      if (event == AuthChangeEvent.signedOut) {
        state = const AsyncData(null);
      }
    });

    return session?.user;
  }

  // ---------------- SIGN IN ----------------
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();

    try {
      final res = await _authService.signIn(
        email: email,
        password: password,
      );

      state = AsyncData(res.user);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  // ---------------- SIGN UP ----------------
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

      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  // ---------------- SIGN OUT ----------------
  Future<void> signOut() async {
    state = const AsyncLoading();

    final prefs = await SharedPreferences.getInstance();

    final keysToKeep = prefs.getKeys().where((k) =>
        k.startsWith('stars_') ||
        k.startsWith('child_rewards_') ||
        k.startsWith('child_equipped_reward_'));

    final preserved = {for (final k in keysToKeep) k: prefs.get(k)};

    await prefs.clear();

    for (final entry in preserved.entries) {
      final v = entry.value;
      if (v is String) await prefs.setString(entry.key, v);
      if (v is int) await prefs.setInt(entry.key, v);
      if (v is bool) await prefs.setBool(entry.key, v);
      if (v is double) await prefs.setDouble(entry.key, v);
    }

    await _authService.signOut();
    state = const AsyncData(null);
  }

  // ---------------- PROFILE ----------------
  Future<Map<String, dynamic>?> getUserProfile() {
    return _authService.getUserProfile();
  }

  Future<String?> getUserRole() async {
    return _authService.getUserRole();
  }

  Future<void> updateProfile({
    String? name,
    String? phone,
    String? avatar,
  }) async {
    state = const AsyncLoading();

    try {
      await _authService.updateProfile(
        name: name,
        phone: phone,
        avatar: avatar,
      );

      // refresh local auth user state (optional but clean)
      final user = Supabase.instance.client.auth.currentUser;
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  // ---------------- DEACTIVATE ----------------
  Future<void> deactivateAccount(String password) async {
    state = const AsyncLoading();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    await _authService.verifyPassword(password);
    await _authService.softDeleteUser();

    state = const AsyncData(null);
  }

  // ---------------- PASSWORD RECOVERY ----------------
  Future<void> recoverPassword(String email) {
    return _authService.resetPassword(email);
  }
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, User?>(() => AuthNotifier());
