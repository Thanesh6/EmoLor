import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

/// Service for managing Supabase connection and operations
class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  
  /// Initialize Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
  }
  
  /// Check if user is authenticated
  static bool get isAuthenticated => client.auth.currentUser != null;
  
  /// Get current user
  static User? get currentUser => client.auth.currentUser;
  
  /// Get current user ID
  static String? get currentUserId => client.auth.currentUser?.id;
}
