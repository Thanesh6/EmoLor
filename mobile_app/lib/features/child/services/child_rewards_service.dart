import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/star_service.dart';

// ── Models ───────────────────────────────────────────────────────────

/// Type of reward the child can earn.
enum RewardType { badge, treasure, theme }

/// A single reward item in the child's gallery.
class ChildReward {
  final String id;
  final String title;
  final String emoji;
  final String description;
  final RewardType type;
  final int colorValue;

  /// For milestone-based rewards: stars needed to auto-unlock.
  final int? milestoneStars;

  /// For treasure-shop rewards: stars to spend.
  final int? starCost;

  /// When the reward was unlocked (null = still locked).
  final DateTime? unlockedAt;

  /// Whether this reward is currently equipped / active.
  final bool isEquipped;

  const ChildReward({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    required this.type,
    required this.colorValue,
    this.milestoneStars,
    this.starCost,
    this.unlockedAt,
    this.isEquipped = false,
  });

  bool get isUnlocked => unlockedAt != null;

  ChildReward copyWith({
    DateTime? unlockedAt,
    bool? isEquipped,
  }) {
    return ChildReward(
      id: id,
      title: title,
      emoji: emoji,
      description: description,
      type: type,
      colorValue: colorValue,
      milestoneStars: milestoneStars,
      starCost: starCost,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      isEquipped: isEquipped ?? this.isEquipped,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'unlockedAt': unlockedAt?.toIso8601String(),
        'isEquipped': isEquipped,
      };
}

// ── Master catalogue ─────────────────────────────────────────────────

/// All rewards available in the child's gallery.
/// Badges unlock automatically at star milestones.
/// Treasures can be purchased with stars.
/// Themes apply a visual change when equipped.
const List<ChildReward> _catalogue = [
  // ── 1 Star ─────────────────────────────────────────────────────
  ChildReward(
    id: 'first_steps',
    title: 'First Steps',
    emoji: '👣',
    description: 'You took your first steps on the adventure!',
    type: RewardType.badge,
    colorValue: 0xFF4ECDC4,
    milestoneStars: 1,
  ),
  // ── 2 Stars ────────────────────────────────────────────────────
  ChildReward(
    id: 'tiny_spark',
    title: 'Tiny Spark',
    emoji: '✨',
    description: 'Your very first spark of light!',
    type: RewardType.badge,
    colorValue: 0xFFFFD700,
    milestoneStars: 2,
  ),
  // ── 3 Stars ────────────────────────────────────────────────────
  ChildReward(
    id: 'happy_smile',
    title: 'Happy Smile',
    emoji: '😊',
    description: 'You made your first happy smile!',
    type: RewardType.badge,
    colorValue: 0xFFFF9F43,
    milestoneStars: 3,
  ),
  // ── 5 Stars ────────────────────────────────────────────────────
  ChildReward(
    id: 'little_star',
    title: 'Little Star',
    emoji: '🌟',
    description: 'You are becoming a little star!',
    type: RewardType.badge,
    colorValue: 0xFFFFE66D,
    milestoneStars: 5,
  ),
  // ── 10 Stars ───────────────────────────────────────────────────
  ChildReward(
    id: 'super_ten',
    title: 'Super Ten!',
    emoji: '🏅',
    description: 'Wow! You collected 10 stars!',
    type: RewardType.badge,
    colorValue: 0xFFFF6B6B,
    milestoneStars: 10,
  ),
  // ── 15 Stars ───────────────────────────────────────────────────
  ChildReward(
    id: 'golden_crown',
    title: 'Golden Crown',
    emoji: '👑',
    description: 'A shining golden crown for a true champion!',
    type: RewardType.treasure,
    colorValue: 0xFFFFD700,
    milestoneStars: 15,
  ),
  // ── 20 Stars ───────────────────────────────────────────────────
  ChildReward(
    id: 'rainbow_heart',
    title: 'Rainbow Heart',
    emoji: '🌈',
    description: 'Your heart shines in every color!',
    type: RewardType.badge,
    colorValue: 0xFFAB47BC,
    milestoneStars: 20,
  ),
  // ── 25 Stars ───────────────────────────────────────────────────
  ChildReward(
    id: 'flower_power',
    title: 'Flower Power',
    emoji: '🌸',
    description: 'You are blossoming beautifully!',
    type: RewardType.treasure,
    colorValue: 0xFFFF7EB3,
    milestoneStars: 25,
  ),
  // ── 30 Stars ───────────────────────────────────────────────────
  ChildReward(
    id: 'magic_wand',
    title: 'Magic Wand',
    emoji: '🪄',
    description: 'Wave your magic wand and feel the magic!',
    type: RewardType.treasure,
    colorValue: 0xFF9C27B0,
    milestoneStars: 30,
  ),
  // ── 35 Stars ───────────────────────────────────────────────────
  ChildReward(
    id: 'butterfly_wings',
    title: 'Butterfly Wings',
    emoji: '🦋',
    description: 'You spread your beautiful wings!',
    type: RewardType.badge,
    colorValue: 0xFF00CEC9,
    milestoneStars: 35,
  ),
  // ── 40 Stars ───────────────────────────────────────────────────
  ChildReward(
    id: 'brave_heart',
    title: 'Brave Heart',
    emoji: '💪',
    description: 'You showed courage and bravery!',
    type: RewardType.badge,
    colorValue: 0xFFE17055,
    milestoneStars: 40,
  ),
  // ── 45 Stars ───────────────────────────────────────────────────
  ChildReward(
    id: 'sunshine_theme',
    title: 'Sunshine Theme',
    emoji: '☀️',
    description: 'Bright and warm like the sun!',
    type: RewardType.theme,
    colorValue: 0xFFFF9F43,
    milestoneStars: 45,
  ),
  // ── 50 Stars ───────────────────────────────────────────────────
  ChildReward(
    id: 'teddy_friend',
    title: 'Teddy Friend',
    emoji: '🧸',
    description: 'You earned a cuddly teddy friend!',
    type: RewardType.treasure,
    colorValue: 0xFFDEB887,
    milestoneStars: 50,
  ),
  // ── 55 Stars ───────────────────────────────────────────────────
  ChildReward(
    id: 'paint_splash',
    title: 'Paint Splash',
    emoji: '🎨',
    description: 'You painted your emotions beautifully!',
    type: RewardType.badge,
    colorValue: 0xFFBB6BD9,
    milestoneStars: 55,
  ),
  // ── 60 Stars ───────────────────────────────────────────────────
  ChildReward(
    id: 'music_maker',
    title: 'Music Maker',
    emoji: '🎵',
    description: 'You found the music in your feelings!',
    type: RewardType.treasure,
    colorValue: 0xFF74B9FF,
    milestoneStars: 60,
  ),
  // ── 65 Stars ───────────────────────────────────────────────────
  ChildReward(
    id: 'ocean_theme',
    title: 'Ocean Theme',
    emoji: '🌊',
    description: 'Dive deep into the ocean adventure!',
    type: RewardType.theme,
    colorValue: 0xFF00838F,
    milestoneStars: 65,
  ),
  // ── 70 Stars ───────────────────────────────────────────────────
  ChildReward(
    id: 'rocket_blast',
    title: 'Rocket Blast',
    emoji: '🚀',
    description: 'Blast off into the emotional galaxy!',
    type: RewardType.badge,
    colorValue: 0xFF1565C0,
    milestoneStars: 70,
  ),
  // ── 75 Stars ───────────────────────────────────────────────────
  ChildReward(
    id: 'forest_theme',
    title: 'Forest Theme',
    emoji: '🌳',
    description: 'Explore the magical enchanted forest!',
    type: RewardType.theme,
    colorValue: 0xFF2E7D32,
    milestoneStars: 75,
  ),
  // ── 80 Stars ───────────────────────────────────────────────────
  ChildReward(
    id: 'crystal_ball',
    title: 'Crystal Ball',
    emoji: '🔮',
    description: 'See your feelings shining inside the crystal!',
    type: RewardType.treasure,
    colorValue: 0xFF7C4DFF,
    milestoneStars: 80,
  ),
  // ── 85 Stars ───────────────────────────────────────────────────
  ChildReward(
    id: 'champion_trophy',
    title: 'Champion Trophy',
    emoji: '🏆',
    description: 'You are the ultimate EmoLor champion!',
    type: RewardType.badge,
    colorValue: 0xFFFF6B81,
    milestoneStars: 85,
  ),
];

// ── Service ──────────────────────────────────────────────────────────

/// Manages the child's reward gallery: unlocking, equipping, purchasing.
///
/// Follows offline-first SharedPreferences pattern (StarService-compatible).
class ChildRewardsService {
  static const _storageKey = 'child_rewards';
  static const _equippedKey = 'child_equipped_reward';

  // ── Read ───────────────────────────────────────────────────────

  /// Returns the full catalogue merged with the child's unlock/equip state.
  static Future<List<ChildReward>> getAllRewards() async {
    final saved = await _loadSavedState();
    final equipped = await _getEquippedId();
    final totalStars = await StarService.getTotalStars();

    return _catalogue.map((r) {
      final state = saved[r.id];
      DateTime? unlockedAt = state?['unlockedAt'] != null
          ? DateTime.tryParse(state!['unlockedAt'])
          : null;

      // Auto-unlock milestone badges based on current stars
      if (unlockedAt == null &&
          r.milestoneStars != null &&
          totalStars >= r.milestoneStars!) {
        unlockedAt = DateTime.now();
        // Persist the auto-unlock (fire and forget)
        _markUnlocked(r.id, unlockedAt);
      }

      return r.copyWith(
        unlockedAt: unlockedAt,
        isEquipped: r.id == equipped,
      );
    }).toList();
  }

  /// Returns only unlocked rewards.
  static Future<List<ChildReward>> getUnlockedRewards() async {
    return (await getAllRewards()).where((r) => r.isUnlocked).toList();
  }

  /// Returns the count of unlocked rewards.
  static Future<int> getUnlockedCount() async {
    return (await getUnlockedRewards()).length;
  }

  /// Returns the currently equipped reward id (or null).
  static Future<String?> getEquippedId() async => _getEquippedId();

  // ── Write ──────────────────────────────────────────────────────

  /// Purchase a treasure / theme with stars. Returns true on success.
  static Future<bool> purchaseReward(String rewardId) async {
    final reward = _catalogue.firstWhere(
      (r) => r.id == rewardId,
      orElse: () => throw ArgumentError('Unknown reward: $rewardId'),
    );

    if (reward.starCost == null) return false;

    final spent = await StarService.spendStars(reward.starCost!);
    if (!spent) return false;

    await _markUnlocked(rewardId, DateTime.now());
    return true;
  }

  /// Equip a reward (theme / avatar). Unequips the previous one.
  static Future<void> equipReward(String rewardId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_equippedKey, rewardId);
  }

  /// Unequip the current reward.
  static Future<void> unequipReward() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_equippedKey);
  }

  // ── Private Helpers ────────────────────────────────────────────

  static Future<Map<String, Map<String, dynamic>>> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return {};
    try {
      final Map<String, dynamic> decoded = jsonDecode(raw);
      return decoded.map(
        (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> _markUnlocked(String id, DateTime when) async {
    final saved = await _loadSavedState();
    saved[id] = {
      'unlockedAt': when.toIso8601String(),
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(saved));
  }

  static Future<String?> _getEquippedId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_equippedKey);
  }

  /// Reset all reward state (debug).
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove(_equippedKey);
  }
}
