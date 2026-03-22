import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lightweight local star‑persistence layer.
///
/// Stars are stored per‑game per‑user and summed on the rewards screen.
/// A simple SharedPreferences backend avoids an extra Supabase table
/// while keeping data across hot‑restarts.
class StarService {
  static String get _prefix {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
    return 'stars_${uid}_';
  }

  // Game keys
  static const emotionPath = 'emotion_path';
  static const safeOrNot = 'safe_or_not';
  static const colorMemory = 'color_memory';
  static const emotionBuilder = 'emotion_builder';
  static const calmGarden = 'calm_garden';
  static const emotionSignals = 'emotion_signals';
  static const emotionBubbles = 'emotion_bubbles';
  static const emojiPuzzle = 'emoji_puzzle';
  static const drawing = 'drawing';
  static const stories = 'stories';
  static const emotionMatch = 'emotion_match';
  static const emojiSpell = 'emoji_spell';
  static const emotionSorting = 'emotion_sorting';
  static const emotionSlash = 'emotion_slash';
  static const emotionCatcher = 'emotion_catcher';

  static final List<String> allGames = [
    emotionPath,
    safeOrNot,
    colorMemory,
    emotionBuilder,
    calmGarden,
    emotionSignals,
    emotionBubbles,
    emojiPuzzle,
    drawing,
    stories,
    emotionMatch,
    emojiSpell,
    emotionSorting,
    emotionSlash,
    emotionCatcher,
  ];

  /// Add [stars] earned from [game]. Stars accumulate without cap.
  static Future<void> addStars(String game, int stars) async {
    if (stars <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('$_prefix$game') ?? 0;
    await prefs.setInt('$_prefix$game', current + stars);
  }

  /// Get total stars earned for [game].
  static Future<int> getStarsForGame(String game) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_prefix$game') ?? 0;
  }

  /// Get grand total across all games.
  static Future<int> getTotalStars() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    int total = 0;
    for (final g in allGames) {
      total += prefs.getInt('$_prefix$g') ?? 0;
    }
    return total;
  }

  /// Star breakdown per game (for rewards screen).
  static Future<Map<String, int>> getBreakdown() async {
    final prefs = await SharedPreferences.getInstance();
    return {for (final g in allGames) g: prefs.getInt('$_prefix$g') ?? 0};
  }

  /// Spend [amount] stars (returns false if not enough).
  static Future<bool> spendStars(int amount) async {
    final total = await getTotalStars();
    if (total < amount) return false;
    // Deduct proportionally from games with most stars
    final prefs = await SharedPreferences.getInstance();
    int remaining = amount;
    for (final g in allGames) {
      if (remaining <= 0) break;
      final cur = prefs.getInt('$_prefix$g') ?? 0;
      final deduct = cur < remaining ? cur : remaining;
      await prefs.setInt('$_prefix$g', cur - deduct);
      remaining -= deduct;
    }
    return true;
  }

  /// Reset all stars (debug).
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final g in allGames) {
      await prefs.remove('$_prefix$g');
    }
  }

  /// Directly set the star count for a specific game (useful for testing).
  static Future<void> setGameStars(String game, int stars) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefix$game', stars);
  }
}
