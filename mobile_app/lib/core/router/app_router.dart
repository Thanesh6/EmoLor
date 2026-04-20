import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Screens
import '../../screens/login_screen.dart';
import '../../screens/register_screen.dart';
import '../../screens/verification_screen.dart';
import '../../screens/forgot_password_screen.dart';
import '../../screens/update_password_screen.dart';
import '../../screens/child_dashboard.dart'; // Child Dashboard
import '../../screens/analytics_dashboard.dart';
import '../../screens/orgz_child_dashboard.dart';
import '../../screens/therapist_dashboard.dart';
import '../../features/child_profile/presentation/child_profile_selection_screen.dart';
import '../../features/child_profile/presentation/create_child_profile_screen.dart';
import '../../features/child/presentation/how_i_feel_screen.dart';
import '../../features/child/presentation/my_colours_screen.dart';
import '../../features/child/presentation/set_goals_screen.dart';

import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/child/presentation/browse_activities_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/link_account_screen.dart';
import '../../features/caregiver/presentation/screens/request_session_screen.dart';
import '../../features/caregiver/presentation/screens/conversation_view_screen.dart';
import '../../features/caregiver/models/chat_message.dart';
import '../../features/caregiver/models/session_request.dart';
import '../../features/therapist/presentation/screens/session_response_screen.dart';
import '../../features/therapist/presentation/screens/schedule_session_screen.dart';
import '../../shared/models/scheduled_session.dart';

/// A ChangeNotifier that listens to Supabase auth state changes.
/// Used as GoRouter's refreshListenable so redirect is re-evaluated
/// WITHOUT recreating the entire GoRouter instance.
class _AuthChangeNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _subscription;

  _AuthChangeNotifier() {
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // Create a notifier that triggers redirect re-evaluation on auth changes.
  // IMPORTANT: Do NOT ref.watch(authProvider) here — that recreates GoRouter
  // on every state change, destroying screens mid-navigation and losing form state.
  final authNotifier = _AuthChangeNotifier();
  ref.onDispose(() => authNotifier.dispose());

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authNotifier,

    redirect: (context, state) async {
      // Read auth state directly from Supabase (avoids Riverpod rebuild loop)
      final client = Supabase.instance.client;
      final isLoggedIn = client.auth.currentSession != null;
      final currentPath = state.uri.toString();

      final isAuthRoute = currentPath == '/login' ||
          currentPath == '/register' ||
          currentPath == '/forgot-password' ||
          currentPath.startsWith('/update-password') ||
          currentPath == '/verification' ||
          currentPath.startsWith('/login-callback');

      // 1. Not Logged In → only allow auth routes
      if (!isLoggedIn) {
        return isAuthRoute ? null : '/login';
      }

      // 2. Logged In & on an auth route → redirect to appropriate dashboard
      if (isAuthRoute) {
        try {
          // If on the verification, email callback, or password reset screen, allow them to stay there
          // Use startsWith for login-callback and update-password because deep links include query params
          if (currentPath == '/verification' ||
              currentPath.startsWith('/login-callback') ||
              currentPath.startsWith('/update-password')) {
            return null;
          }

          // If email is not confirmed yet (and they're not explicitly on the verification screen),
          // don't let them securely enter the app
          if (client.auth.currentUser?.emailConfirmedAt == null) {
              return null; // they will need to verify or sign out
          }

          final userId = client.auth.currentUser!.id;
          final userEmail = client.auth.currentUser!.email?.toLowerCase() ?? '';
          final response = await client
              .rpc('get_user_role', params: {'p_user_id': userId})
              .single();

          final role = response['role'] as String?;
          final accountType =
              (response['account_type'] as String?)?.toLowerCase();

          // Admin gate: only the designated admin email may access admin
          if (role == 'admin') {
            if (userEmail == 'admint@gmail.com') {
              return '/admin-dashboard';
            } else {
              // Non-authorised admin role → sign out
              await client.auth.signOut();
              return '/login';
            }
          }

          if (role == 'therapist') return '/therapist-dashboard';
          if (role == 'caregiver' && accountType == 'organization') {
            return '/orgz-child-dashboard';
          }
        } catch (e) {
          debugPrint('Error fetching role in redirect: $e');
        }
        return '/child/home'; // Default for caregivers (single child)
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/verification',
        builder: (context, state) {
          final email = state.extra as String? ?? 'your email';
          return VerificationScreen(email: email);
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/update-password', // For Deep Link
        builder: (context, state) => const UpdatePasswordScreen(),
      ),
      // Email confirmation deep link: emolor://login-callback/?token_hash=...&type=signup
      GoRoute(
        path: '/login-callback',
        builder: (context, state) => const _EmailConfirmCallbackScreen(),
      ),
      // Dashboards
      //
      // NOTE: the old '/child-dashboard' path has been removed — it pointed
      // at the same ChildDashboard widget as '/child/home' but with no
      // `extra`, which silently hid the Switch Account button for org
      // caregivers. Everything now routes through '/child/home'.
      GoRoute(
        path: '/child-profiles',
        builder: (context, state) => const ChildProfileSelectionScreen(),
      ),
      GoRoute(
        path: '/child/create',
        builder: (context, state) => const CreateChildProfileScreen(),
      ),
      GoRoute(
        path: '/child/home',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ChildDashboard(
            showSwitchAccount: extra?['showSwitch'] == true,
            childName: extra?['childName'] as String?,
          );
        },
      ),
      // Goal-setting screen — shown right after profile selection,
      // before the mood check-in. Both goals are optional (child can skip).
      GoRoute(
        path: '/child/set-goals',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final childName = extra?['childName'] as String?;
          final showSwitch = extra?['showSwitch'] == true;
          return SetGoalsScreen(
            childName: childName,
            onBack: () {
              if (showSwitch) {
                context.go('/orgz-child-dashboard');
              } else {
                context.go('/child-profiles');
              }
            },
            onContinue: () {
              context.go('/how-i-feel-start', extra: {
                'childName': childName,
                'showSwitch': showSwitch,
              });
            },
          );
        },
      ),
      // Phase 1 — "How do you feel today?" shown right after goal setup.
      GoRoute(
        path: '/how-i-feel-start',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final childName = extra?['childName'] as String?;
          final showSwitch = extra?['showSwitch'] == true;
          return HowIFeelScreen(
            mode: HowIFeelMode.start,
            childName: childName,
            // Back goes to the profile picker the child came from —
            // org accounts return to /orgz-child-dashboard, otherwise
            // to /child-profiles.
            onBack: () {
              if (showSwitch) {
                context.go('/orgz-child-dashboard');
              } else {
                context.go('/child-profiles');
              }
            },
            onContinue: (_) async {
              // Move to Phase 2 — My Colours setup.
              if (context.mounted) {
                context.go('/my-colours-setup', extra: {
                  'childName': childName,
                  'showSwitch': showSwitch,
                });
              }
            },
          );
        },
      ),
      // Phase 2 — "My Colours" onboarding picker before the dashboard.
      GoRoute(
        path: '/my-colours-setup',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final childName = extra?['childName'] as String?;
          final showSwitch = extra?['showSwitch'] == true;
          return MyColoursScreen(
            isOnboarding: true,
            onFinished: () {
              // Enter the main dashboard.
              context.go('/child/home', extra: {
                'childName': childName,
                'showSwitch': showSwitch,
              });
            },
          );
        },
      ),
      // Post-session — "How are you feeling now?" shown before logout /
      // switch / goal-time end.
      GoRoute(
        path: '/how-i-feel-end',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final childName = extra?['childName'] as String?;
          // Action to perform after the child picks their mood.
          // Options: 'logout' (sign out), 'switch' (go to org dashboard),
          // 'back-to-profiles' (go to profile selection).
          final action = (extra?['action'] as String?) ?? 'logout';
          return HowIFeelScreen(
            mode: HowIFeelMode.end,
            childName: childName,
            onContinue: (_) async {
              if (!context.mounted) return;
              switch (action) {
                case 'switch':
                  context.go('/orgz-child-dashboard');
                  break;
                case 'back-to-profiles':
                  context.go('/child-profiles');
                  break;
                case 'logout':
                default:
                  await Supabase.instance.client.auth.signOut();
                  // GoRouter redirect will take them to /login.
                  break;
              }
            },
          );
        },
      ),
      GoRoute(
        path: '/caregiver-dashboard',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AnalyticsDashboard(
            childName: extra?['childName'] as String?,
            showSwitchAccount: extra?['showSwitch'] == true,
          );
        },
      ),
      GoRoute(
        path: '/orgz-child-dashboard',
        builder: (context, state) => const OrgzChildDashboard(),
      ),
      // Centre analytics dashboard — accessed from child dashboard via PIN gate.
      // Uses the NEW AnalyticsDashboard (full tabbed UI, PDF export).
      GoRoute(
        path: '/centre-dashboard',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AnalyticsDashboard(
            childName: extra?['childName'] as String?,
            showSwitchAccount: extra?['showSwitch'] == true,
          );
        },
      ),
      GoRoute(
        path: '/therapist-dashboard',
        builder: (context, state) => const TherapistDashboard(),
      ),
      GoRoute(
        path: '/admin-dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/browse-activities',
        builder: (context, state) => const BrowseActivitiesScreen(),
      ),
      // Profile Management
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/link-account',
        builder: (context, state) => const LinkAccountScreen(),
      ),
      GoRoute(
        path: '/request-session',
        builder: (context, state) => const RequestSessionScreen(),
      ),
      // UCD031 – View Message / Feedback
      GoRoute(
        path: '/conversation-view',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ConversationViewScreen(
            conversation: extra['conversation'] as Conversation,
            contactName: extra['contactName'] as String,
            contactRole: extra['contactRole'] as String,
          );
        },
      ),
      // UCD033 – Respond To Session Invitation
      GoRoute(
        path: '/session-response',
        builder: (context, state) {
          final request = state.extra as SessionRequest;
          return SessionResponseScreen(request: request);
        },
      ),
      // UCD034 – Schedule Session
      GoRoute(
        path: '/schedule-session',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ScheduleSessionScreen(
            prefilledDate: extra?['prefilledDate'] as DateTime?,
            prefilledSlot: extra?['prefilledSlot'] as SessionTimeSlot?,
            prefilledCaregiverId: extra?['prefilledCaregiverId'] as String?,
            prefilledChildProfileId:
                extra?['prefilledChildProfileId'] as String?,
            prefilledTitle: extra?['prefilledTitle'] as String?,
            sessionRequestId: extra?['sessionRequestId'] as String?,
          );
        },
      ),
    ],
    // DEBUG: Print errors
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Error: ${state.error}')),
    ),
  );
});

/// Handles the emolor://login-callback/ deep link from Supabase email confirmation.
/// Exchanges the token in the URL for a Supabase session, then go_router
/// redirects to the appropriate dashboard via its redirect logic.
class _EmailConfirmCallbackScreen extends StatefulWidget {
  const _EmailConfirmCallbackScreen();

  @override
  State<_EmailConfirmCallbackScreen> createState() =>
      _EmailConfirmCallbackScreenState();
}

class _EmailConfirmCallbackScreenState
    extends State<_EmailConfirmCallbackScreen> {
  String _status = 'Confirming your email…';

  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    try {
      // Wait for Supabase to process the deep link token
      await Future.delayed(const Duration(seconds: 2));

      // Sign out so user is NOT auto-logged-in — they should login manually
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}

      if (mounted) {
        setState(() => _status = '✅ Email confirmed! Please log in.');
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Something went wrong. Please log in.');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFBAE6FD), Color(0xFFE9D5FF)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF6B21A8)),
              const SizedBox(height: 24),
              Text(
                _status,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B21A8),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
