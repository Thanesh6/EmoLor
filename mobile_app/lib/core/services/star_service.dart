import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight local star‑persistence layer.
///
/// Stars are stored per‑game per child profile and summed on the rewards
/// screen. A simple SharedPreferences backend avoids an extra Supabase table
/// while keeping data across hot‑restarts.
///
/// The storage prefix is keyed off the currently selected child profile id
/// (`selected_child_profile_id`) so multiple children under the same
/// caregiver/org account each maintain their own star totals. If no profile
/// is selected we fall back to a sentinel `'no_profile'` bucket — never to
/// the caregiver auth uid, which would cause sibling children to share data.
class StarService {
  static const _profileIdKey = 'selected_child_profile_id';

  static Future<String> _prefixAsync() async {
    final prefs = await SharedPreferences.getInstance();
    final profileId = prefs.getString(_profileIdKey) ?? 'no_profile';
    return 'stars_${profileId}_';
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
  static const animalSound = 'animal_sound';
  static const emoMatch = 'emo_match';

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
    animalSound,
    emoMatch,
  ];

  /// Add [stars] earned from [game]. Stars accumulate without cap.
  static Future<void> addStars(String game, int stars) async {
    if (stars <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final prefix = await _prefixAsync();
    final current = prefs.getInt('$prefix$game') ?? 0;
    await prefs.setInt('$prefix$game', current + stars);
  }

  /// Get total stars earned for [game].
  static Future<int> getStarsForGame(String game) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = await _prefixAsync();
    return prefs.getInt('$prefix$game') ?? 0;
  }

  /// Get grand total across all games.
  static Future<int> getTotalStars() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final prefix = await _prefixAsync();
    int total = 0;
    for (final g in allGames) {
      total += prefs.getInt('$prefix$g') ?? 0;
    }
    return total;
  }

  /// Star breakdown per game (for rewards screen).
  static Future<Map<String, int>> getBreakdown() async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = await _prefixAsync();
    return {for (final g in allGames) g: prefs.getInt('$prefix$g') ?? 0};
  }

  /// Spend [amount] stars (returns false if not enough).
  static Future<bool> spendStars(int amount) async {
    final total = await getTotalStars();
    if (total < amount) return false;
    // Deduct proportionally from games with most stars
    final prefs = await SharedPreferences.getInstance();
    final prefix = await _prefixAsync();
    int remaining = amount;
    for (final g in allGames) {
      if (remaining <= 0) break;
      final cur = prefs.getInt('$prefix$g') ?? 0;
      final deduct = cur < remaining ? cur : remaining;
      await prefs.setInt('$prefix$g', cur - deduct);
      remaining -= deduct;
    }
    return true;
  }

  /// Reset all stars (debug).
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = await _prefixAsync();
    for (final g in allGames) {
      await prefs.remove('$prefix$g');
    }
  }

  /// Directly set the star count for a specific game (useful for testing).
  static Future<void> setGameStars(String game, int stars) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = await _prefixAsync();
    await prefs.setInt('$prefix$game', stars);
  }
}
