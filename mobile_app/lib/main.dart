import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/supabase_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/emotion_colour_mapping.dart';
import 'core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await EmotionColourMapping.ensureLoaded();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // Deep-link recovery: Supabase auto-processes the access_token in the
    // URL fragment when the app opens via emolor://update-password/...,
    // then fires passwordRecovery. We catch it here and navigate the
    // user to the update-password screen (otherwise the GoRouter redirect
    // would treat them as "logged in" and send them to the dashboard).
    _authSub =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      // Password-recovery deep-link → update-password screen
      if (data.event == AuthChangeEvent.passwordRecovery) {
        final router = ref.read(appRouterProvider);
        router.go('/update-password');
        return;
      }

      // Email-change confirmation deep-link → sign out, force manual login.
      // The in-app "Change Email & Password" dialog also fires userUpdated
      // when it calls updateUser; that one is flagged to be ignored here so
      // only the deep-link confirmation triggers the redirect.
      if (data.event == AuthChangeEvent.userUpdated) {
        if (AuthService.ignoreNextUserUpdated) {
          AuthService.ignoreNextUserUpdated = false;
          return;
        }
        try {
          await Supabase.instance.client.auth.signOut();
        } catch (_) {}
        if (!mounted) return;
        ref.read(appRouterProvider).go('/login');
        return;
      }

      // Email-verification deep-link → sign out and force manual login.
      // Supabase auto-fires signedIn after the user clicks the verification
      // link. We detect this by checking if the email was confirmed and
      // the sign-in happened within ~10 seconds of each other.
      if (data.event == AuthChangeEvent.signedIn) {
        final user = data.session?.user;
        if (user == null) return;

        final confirmedAtStr = user.emailConfirmedAt;
        final lastSignInStr = user.lastSignInAt;
        if (confirmedAtStr == null || lastSignInStr == null) return;

        try {
          final confirmedAt = DateTime.parse(confirmedAtStr);
          final lastSignIn = DateTime.parse(lastSignInStr);
          final diff = lastSignIn.difference(confirmedAt).abs();

          // Within 10 s → this is a fresh email verification, not a normal login
          if (diff.inSeconds <= 10) {
            await Supabase.instance.client.auth.signOut();
            if (!mounted) return;
            final router = ref.read(appRouterProvider);
            router.go('/login');
          }
        } catch (_) {
          // Timestamp parsing failed → fall through to normal sign-in flow
        }
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      routerConfig: router,
      title: 'EmoLor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
    );
  }
}
