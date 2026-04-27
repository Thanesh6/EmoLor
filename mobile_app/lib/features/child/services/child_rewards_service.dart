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
  // ══════════════════════════════════════════════════════════════════
  // EARLY REWARDS — 10 to 400 stars (easy wins to build momentum)
  // ══════════════════════════════════════════════════════════════════

  // ── 10 Stars ───────────────────────────────────────────────────
  ChildReward(
    id: 'first_steps',
    title: 'First Steps',
    emoji: '👣',
    description: 'You took your first steps on the adventure!',
    type: RewardType.badge,
    colorValue: 0xFF4ECDC4,
    milestoneStars: 10,
  ),
  // ── 25 Stars ───────────────────────────────────────────────────
  ChildReward(
    id: 'tiny_spark',
    title: 'Tiny Spark',
    emoji: '✨',
    description: 'Your very first spark of light!',
    type: RewardType.badge,
    colorValue: 0xFFFFD700,
    milestoneStars: 25,
  ),
  // ── 50 Stars ───────────────────────────────────────────────────
  ChildReward(
    id: 'happy_smile',
    title: 'Happy Smile',
    emoji: '😊',
    description: 'You made your first happy smile!',
    type: RewardType.badge,
    colorValue: 0xFFFF9F43,
    milestoneStars: 50,
  ),
  // ── 75 Stars ───────────────────────────────────────────────────
  ChildReward(
    id: 'little_star',
    title: 'Little Star',
    emoji: '🌟',
    description: 'You are becoming a little star!',
    type: RewardType.badge,
    colorValue: 0xFFFFE66D,
    milestoneStars: 75,
  ),
  // ── 100 Stars ──────────────────────────────────────────────────
  ChildReward(
    id: 'super_ten',
    title: 'Century Star',
    emoji: '🏅',
    description: 'Wow! You collected 100 stars! You\'re on fire!',
    type: RewardType.badge,
    colorValue: 0xFFFF6B6B,
    milestoneStars: 100,
  ),
  // ── 150 Stars ──────────────────────────────────────────────────
  ChildReward(
    id: 'golden_crown',
    title: 'Golden Crown',
    emoji: '👑',
    description: 'A shining golden crown for a true champion!',
    type: RewardType.treasure,
    colorValue: 0xFFFFD700,
    milestoneStars: 150,
  ),
  // ── 200 Stars ──────────────────────────────────────────────────
  ChildReward(
    id: 'rainbow_heart',
    title: 'Rainbow Heart',
    emoji: '🌈',
    description: 'Your heart shines in every color!',
    type: RewardType.badge,
    colorValue: 0xFFAB47BC,
    milestoneStars: 200,
  ),
  // ── 250 Stars ──────────────────────────────────────────────────
  ChildReward(
    id: 'flower_power',
    title: 'Flower Power',
    emoji: '🌸',
    description: 'You are blossoming beautifully!',
    type: RewardType.treasure,
    colorValue: 0xFFFF7EB3,
    milestoneStars: 250,
  ),
  // ── 300 Stars ──────────────────────────────────────────────────
  ChildReward(
    id: 'magic_wand',
    title: 'Magic Wand',
    emoji: '🪄',
    description: 'Wave your magic wand and feel the magic!',
    type: RewardType.treasure,
    colorValue: 0xFF9C27B0,
    milestoneStars: 300,
  ),
  // ── 400 Stars ──────────────────────────────────────────────────
  ChildReward(
    id: 'butterfly_wings',
    title: 'Butterfly Wings',
    emoji: '🦋',
    description: 'You spread your beautiful wings!',
    type: RewardType.badge,
    colorValue: 0xFF00CEC9,
    milestoneStars: 400,
  ),

  // ══════════════════════════════════════════════════════════════════
  // MIDDLE REWARDS — 500 to 1650 stars (moderate effort)
  // ══════════════════════════════════════════════════════════════════

  // ── 500 Stars ──────────────────────────────────────────────────
  ChildReward(
    id: 'brave_heart',
    title: 'Brave Heart',
    emoji: '💪',
    description: 'You showed incredible courage and bravery!',
    type: RewardType.badge,
    colorValue: 0xFFE17055,
    milestoneStars: 500,
  ),
  // ── 650 Stars ──────────────────────────────────────────────────
  ChildReward(
    id: 'sunshine_theme',
    title: 'Sunshine Theme',
    emoji: '☀️',
    description: 'Bright and warm like the sun!',
    type: RewardType.theme,
    colorValue: 0xFFFF9F43,
    milestoneStars: 650,
  ),
  // ── 800 Stars ──────────────────────────────────────────────────
  ChildReward(
    id: 'teddy_friend',
    title: 'Teddy Friend',
    emoji: '🧸',
    description: 'You earned a cuddly teddy friend!',
    type: RewardType.treasure,
    colorValue: 0xFFDEB887,
    milestoneStars: 800,
  ),
  // ── 1000 Stars ─────────────────────────────────────────────────
  ChildReward(
    id: 'paint_splash',
    title: 'Paint Splash',
    emoji: '🎨',
    description: 'You painted your emotions beautifully!',
    type: RewardType.badge,
    colorValue: 0xFFBB6BD9,
    milestoneStars: 1000,
  ),
  // ── 1100 Stars ─────────────────────────────────────────────────
  ChildReward(
    id: 'music_maker',
    title: 'Music Maker',
    emoji: '🎵',
    description: 'You found the music in your feelings!',
    type: RewardType.treasure,
    colorValue: 0xFF74B9FF,
    milestoneStars: 1100,
  ),
  // ── 1200 Stars ─────────────────────────────────────────────────
  ChildReward(
    id: 'ocean_theme',
    title: 'Ocean Theme',
    emoji: '🌊',
    description: 'Dive deep into the ocean adventure!',
    type: RewardType.theme,
    colorValue: 0xFF00838F,
    milestoneStars: 1200,
  ),
  // ── 1300 Stars ─────────────────────────────────────────────────
  ChildReward(
    id: 'rocket_blast',
    title: 'Rocket Blast',
    emoji: '🚀',
    description: 'Blast off into the emotional galaxy!',
    type: RewardType.badge,
    colorValue: 0xFF1565C0,
    milestoneStars: 1300,
  ),
  // ── 1400 Stars ─────────────────────────────────────────────────
  ChildReward(
    id: 'forest_theme',
    title: 'Forest Theme',
    emoji: '🌳',
    description: 'Explore the magical enchanted forest!',
    type: RewardType.theme,
    colorValue: 0xFF2E7D32,
    milestoneStars: 1400,
  ),
  // ── 1500 Stars ─────────────────────────────────────────────────
  ChildReward(
    id: 'crystal_ball',
    title: 'Crystal Ball',
    emoji: '🔮',
    description: 'See your feelings shining inside the crystal!',
    type: RewardType.treasure,
    colorValue: 0xFF7C4DFF,
    milestoneStars: 1500,
  ),
  // ── 1650 Stars ─────────────────────────────────────────────────
  ChildReward(
    id: 'champion_trophy',
    title: 'Champion Trophy',
    emoji: '🏆',
    description: 'You are a true EmoLor champion!',
    type: RewardType.badge,
    colorValue: 0xFFFF6B81,
    milestoneStars: 1650,
  ),

  // ══════════════════════════════════════════════════════════════════
  // LATE REWARDS — 1750 to 5000 stars (hardest, most prestigious)
  // ══════════════════════════════════════════════════════════════════

  // ── 1750 Stars ─────────────────────────────────────────────────
  ChildReward(
    id: 'star_explorer',
    title: 'Star Explorer',
    emoji: '🌠',
    description: 'You have explored the farthest reaches of the sky!',
    type: RewardType.badge,
    colorValue: 0xFF5C6BC0,
    milestoneStars: 1750,
  ),
  // ── 2000 Stars ─────────────────────────────────────────────────
  ChildReward(
    id: 'dragon_friend',
    title: 'Dragon Friend',
    emoji: '🐉',
    description: 'A mighty dragon bows to your emotional strength!',
    type: RewardType.treasure,
    colorValue: 0xFF388E3C,
    milestoneStars: 2000,
  ),
  // ── 2250 Stars ─────────────────────────────────────────────────
  ChildReward(
    id: 'rainbow_wizard',
    title: 'Rainbow Wizard',
    emoji: '🧙',
    description: 'You cast spells of kindness and understanding!',
    type: RewardType.theme,
    colorValue: 0xFF7B1FA2,
    milestoneStars: 2250,
  ),
  // ── 2500 Stars ─────────────────────────────────────────────────
  ChildReward(
    id: 'space_commander',
    title: 'Space Commander',
    emoji: '👨‍🚀',
    description: 'Commander of the emotional universe!',
    type: RewardType.badge,
    colorValue: 0xFF0277BD,
    milestoneStars: 2500,
  ),
  // ── 2750 Stars ─────────────────────────────────────────────────
  ChildReward(
    id: 'golden_phoenix',
    title: 'Golden Phoenix',
    emoji: '🔥',
    description: 'You rise stronger every single time!',
    type: RewardType.badge,
    colorValue: 0xFFEF6C00,
    milestoneStars: 2750,
  ),
  // ── 3000 Stars ─────────────────────────────────────────────────
  ChildReward(
    id: 'diamond_shield',
    title: 'Diamond Shield',
    emoji: '💎',
    description: 'Your emotional resilience is unbreakable!',
    type: RewardType.treasure,
    colorValue: 0xFF00ACC1,
    milestoneStars: 3000,
  ),
  // ── 3500 Stars ─────────────────────────────────────────────────
  ChildReward(
    id: 'mystic_dragon',
    title: 'Mystic Dragon',
    emoji: '🌋',
    description: 'Ancient wisdom and fierce feelings — all yours!',
    type: RewardType.theme,
    colorValue: 0xFFC62828,
    milestoneStars: 3500,
  ),
  // ── 4000 Stars ─────────────────────────────────────────────────
  ChildReward(
    id: 'cosmic_legend',
    title: 'Cosmic Legend',
    emoji: '🌌',
    description: 'A legend written across the stars themselves!',
    type: RewardType.badge,
    colorValue: 0xFF283593,
    milestoneStars: 4000,
  ),
  // ── 4500 Stars ─────────────────────────────────────────────────
  ChildReward(
    id: 'eternal_star',
    title: 'Eternal Star',
    emoji: '💫',
    description: 'Your light will shine forever and ever!',
    type: RewardType.treasure,
    colorValue: 0xFFF9A825,
    milestoneStars: 4500,
  ),
  // ── 5000 Stars ─────────────────────────────────────────────────
  ChildReward(
    id: 'emolor_master',
    title: 'EmoLor Master',
    emoji: '🌟',
    description: 'The ultimate EmoLor achievement — you mastered your emotions!',
    type: RewardType.badge,
    colorValue: 0xFF6D28D9,
    milestoneStars: 5000,
  ),
];

// ── Service ──────────────────────────────────────────────────────────

/// Manages the child's reward gallery: unlocking, equipping, purchasing.
///
/// Follows offline-first SharedPreferences pattern (StarService-compatible).
class ChildRewardsService {
  static const _profileIdKey = 'selected_child_profile_id';

  /// Per-child reward state keys. Without this, every child profile
  /// inherits the previous child's unlocks — and the auto-unlock logic
  /// in [getAllRewards] then permanently writes them into the global
  /// bucket.
  static Future<String> _storageKeyAsync() async {
    final prefs = await SharedPreferences.getInstance();
    final profileId = prefs.getString(_profileIdKey) ?? 'no_profile';
    return 'child_rewards_$profileId';
  }

  static Future<String> _equippedKeyAsync() async {
    final prefs = await SharedPreferences.getInstance();
    final profileId = prefs.getString(_profileIdKey) ?? 'no_profile';
    return 'child_equipped_reward_$profileId';
  }

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
    final key = await _equippedKeyAsync();
    await prefs.setString(key, rewardId);
  }

  /// Unequip the current reward.
  static Future<void> unequipReward() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _equippedKeyAsync();
    await prefs.remove(key);
  }

  // ── Private Helpers ────────────────────────────────────────────

  static Future<Map<String, Map<String, dynamic>>> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _storageKeyAsync();
    final raw = prefs.getString(key);
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
    final key = await _storageKeyAsync();
    await prefs.setString(key, jsonEncode(saved));
  }

  static Future<String?> _getEquippedId() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _equippedKeyAsync();
    return prefs.getString(key);
  }

  /// Reset all reward state for the current child profile.
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = await _storageKeyAsync();
    final equippedKey = await _equippedKeyAsync();
    await prefs.remove(storageKey);
    await prefs.remove(equippedKey);
  }
}
