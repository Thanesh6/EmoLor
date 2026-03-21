import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/services/supabase_service.dart';
import 'core/services/emotion_colour_mapping.dart';
import 'core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await EmotionColourMapping.ensureLoaded();

  // One-time reset of stars, rewards, and game progress for testing.
  // Remove this block once testing is complete.
  final prefs = await SharedPreferences.getInstance();
  final hasReset = prefs.getBool('_test_reset_v4') ?? false;
  if (!hasReset) {
    // Nuclear clear: remove ALL star, reward, and progress keys
    final allKeys = prefs.getKeys().toList();
    for (final k in allKeys) {
      if (k.startsWith('stars_') ||
          k.startsWith('activity_progress_') ||
          k.startsWith('child_rewards') ||
          k.startsWith('child_equipped') ||
          k.startsWith('_test_reset_')) {
        await prefs.remove(k);
      }
    }
    await prefs.setBool('_test_reset_v4', true);
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
