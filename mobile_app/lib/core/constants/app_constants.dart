/// App-wide constants
class AppConstants {
  // App Info
  static const String appName = 'EmoLor';
  static const String appVersion = '1.0.0';

  // Supabase Configuration
  // TODO: Move these to environment variables for production
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://chcevgwoyfffiqeqwbde.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNoY2V2Z3dveWZmZmlxZXF3YmRlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEzODMxMjQsImV4cCI6MjA3Njk1OTEyNH0.XfOGBCWNujNpmlZDsqz6je7sQEIbaVliUmcKHb4R1oQ',
  );

  // User Roles (Children don't have auth accounts, only profiles)
  static const String roleCaregiver = 'caregiver';

  // Routes
  static const String routeSplash = '/';
  static const String routeLogin = '/login';
  static const String routeAbout = '/about';
  static const String routeProfileSelect = '/profile-select';
  static const String routeChildHome = '/child/home';
  static const String routeChildCreate = '/child/create';
  static const String routeCaregiver = '/caregiver';
  static const String routeSessionResponse = '/session-response';
  static const String routeScheduleSession = '/schedule-session';
  static const String routeModerationQueue = '/moderation-queue';
  static const String routeCommConfig = '/comm-config';
  static const String routeSessionOversight = '/session-oversight';
  static const String routeClientRecord = '/client-record';

  // Storage Keys
  static const String keyUserRole = 'user_role';
  static const String keyUserId = 'user_id';
  static const String keySelectedChildProfile = 'selected_child_profile';
  static const String keyLanguage = 'language';

  // Supported Languages
  static const List<String> supportedLanguages = ['en', 'ms', 'ta', 'zh'];
  static const String defaultLanguage = 'en';
}
