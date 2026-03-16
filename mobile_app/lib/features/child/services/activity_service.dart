import '../models/activity.dart';
import '../models/activity_item.dart';
import 'package:flutter/foundation.dart';

class ActivityService {
  // final SupabaseClient _client = SupabaseService.client;

  Future<List<Activity>> getActivitiesByType(String type) async {
    try {
      // DEV MODE: Return dummy data if no connection or empty
      // This ensures the UI works even without DB setup
      if (true) {
        // Force dummy data for now as requested by user flow
        return _getDummyActivities(type);
      }

      /* 
      // Real implementation
      final response = await _client
          .from('activities')
          .select()
          .eq('activity_type', type)
          .eq('is_active', true);

      return (response as List)
          .map((json) => Activity.fromJson(json))
          .toList();
      */
    } catch (e) {
      return _getDummyActivities(type);
    }
  }

  List<Activity> _getDummyActivities(String type) {
    switch (type) {
      case 'game':
        return [
          Activity(
            id: '1',
            title: 'Feeling Faces',
            description: 'Match the face to the emotion!',
            type: 'game',
            difficulty: 'easy',
            durationMinutes: 5,
            thumbnailUrl: 'assets/images/cartoon_cat.png', // Placeholder
          ),
          Activity(
            id: '2',
            title: 'Mood Monster',
            description: 'Help the monster find its mood.',
            type: 'game',
            difficulty: 'medium',
            durationMinutes: 10,
            thumbnailUrl: 'assets/images/cartoon_cat.png', // Placeholder
          ),
          Activity(
            id: '3',
            title: 'Color Sort',
            description: 'Sort items by their feeling color.',
            type: 'game',
            difficulty: 'easy',
            durationMinutes: 5,
            thumbnailUrl: 'assets/images/cartoon_cat.png', // Placeholder
          ),
        ];
      case 'art':
        return [
          Activity(
            id: '4',
            title: 'Free Draw',
            description: 'Draw whatever you feel!',
            type: 'art',
            difficulty: 'easy',
            durationMinutes: 15,
            thumbnailUrl: 'assets/images/cartoon_cat.png', // Placeholder
          ),
          Activity(
            id: '5',
            title: 'Coloring Book',
            description: 'Color the happy scenes.',
            type: 'art',
            difficulty: 'easy',
            durationMinutes: 10,
            thumbnailUrl: 'assets/images/cartoon_cat.png', // Placeholder
          ),
        ];
      case 'story':
        return [
          Activity(
            id: '6',
            title: 'The Brave Lion',
            description: 'A story about being brave.',
            type: 'story',
            difficulty: 'easy',
            durationMinutes: 8,
            thumbnailUrl: 'assets/images/cartoon_cat.png', // Placeholder
          ),
        ];
      case 'music': // mapped from 'exercise' or custom type
        return [
          Activity(
            id: '7',
            title: 'Calm Sounds',
            description: 'Listen to soothing nature sounds.',
            type: 'music',
            difficulty: 'easy',
            durationMinutes: 10,
            thumbnailUrl: 'assets/images/cartoon_cat.png', // Placeholder
          ),
        ];
      default:
        return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UCD012 – Browse Learning Activities
  // ═══════════════════════════════════════════════════════════════════════

  /// Master catalogue of fixed activities (Games, Drawing, Stories).
  /// UCD012 Main Flow step 1.
  static const List<ActivityItem> _catalogue = [
    // ── Games ─────────────────────────────────────────────────────────
    ActivityItem(
      id: 'game_emotion_path',
      name: 'Emotion Path',
      emoji: '🧭',
      description: 'Walk through paths of emotion!',
      category: ActivityCategory.games,
      gradientColors: [0xFF4ECDC4, 0xFF2AB7A9],
    ),
    ActivityItem(
      id: 'game_safe_or_not',
      name: 'Safe or Not?',
      emoji: '🤔',
      description: 'Judge feelings & situations!',
      category: ActivityCategory.games,
      gradientColors: [0xFFFF9F43, 0xFFEE8B2A],
    ),
    ActivityItem(
      id: 'game_color_memory',
      name: 'Color Memory',
      emoji: '🧠',
      description: 'Remember the color patterns!',
      category: ActivityCategory.games,
      gradientColors: [0xFFBB6BD9, 0xFF9B51C6],
    ),
    ActivityItem(
      id: 'game_bubble_pop',
      name: 'Bubble Pop',
      emoji: '🫧',
      description: 'Pop the right feeling!',
      category: ActivityCategory.games,
      gradientColors: [0xFFFF7EB3, 0xFFFF5A9E],
    ),
    ActivityItem(
      id: 'game_calm_garden',
      name: 'Calm Garden',
      emoji: '🌱',
      description: 'Grow a peaceful garden!',
      category: ActivityCategory.games,
      gradientColors: [0xFF7ED957, 0xFF5EC03A],
      isSuggested: true, // Adaptive Engine hint: calming activity
    ),
    ActivityItem(
      id: 'game_emotion_signals',
      name: 'Emotion Signals',
      emoji: '🔮',
      description: 'Spot the hidden signal!',
      category: ActivityCategory.games,
      gradientColors: [0xFF5D9CEC, 0xFF4388DA],
    ),

    // ── Drawing ───────────────────────────────────────────────────────
    ActivityItem(
      id: 'draw_free',
      name: 'Free Draw',
      emoji: '🖌️',
      description: 'Express yourself with colors!',
      category: ActivityCategory.drawing,
      gradientColors: [0xFF60A5FA, 0xFF3B82F6],
    ),
    ActivityItem(
      id: 'draw_calm',
      name: 'Calm Drawing',
      emoji: '🌊',
      description: 'Draw soothing shapes quietly.',
      category: ActivityCategory.drawing,
      gradientColors: [0xFF93C5FD, 0xFF6BB3F7],
      isSuggested: true, // Adaptive Engine: calm suggestion
    ),

    // ── Stories ───────────────────────────────────────────────────────
    ActivityItem(
      id: 'story_happy_cloud',
      name: 'The Happy Cloud',
      emoji: '☁️',
      description: 'A cloud that finds its smile.',
      category: ActivityCategory.stories,
      gradientColors: [0xFF87CEEB, 0xFF6DB9D8],
    ),
    ActivityItem(
      id: 'story_brave_bear',
      name: 'Brave Little Bear',
      emoji: '🐻',
      description: 'A bear learns to be brave.',
      category: ActivityCategory.stories,
      gradientColors: [0xFFDEB887, 0xFFCCA870],
    ),
    ActivityItem(
      id: 'story_rainbow_friends',
      name: 'Rainbow Friends',
      emoji: '🌈',
      description: 'Friends celebrate differences!',
      category: ActivityCategory.stories,
      gradientColors: [0xFFFF6B6B, 0xFFE55555],
    ),
  ];

  /// Returns the full activity catalogue.
  /// On error, falls back to the hardcoded offline backup (UCD012 alt-flow).
  Future<List<ActivityItem>> getAllActivities() async {
    try {
      // In production this would hit Supabase to fetch the latest list +
      // play-history. For now, simulate a short network delay and return
      // the local catalogue.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return List.of(_catalogue);
    } catch (e) {
      debugPrint('ActivityService.getAllActivities error: $e');
      // UCD012 Alt-Flow: return offline backup
      return List.of(_catalogue);
    }
  }

  /// Applies Adaptive Sensory Engine hints (UCD012 step 2).
  /// Returns a copy of [activities] with appropriate items marked suggested.
  List<ActivityItem> applyAdaptiveHints(List<ActivityItem> activities) {
    // Placeholder: in production, consult AdaptiveEngine to determine state.
    // Currently keeps catalogue defaults (Calm Garden & Calm Drawing flagged).
    return activities;
  }
}
