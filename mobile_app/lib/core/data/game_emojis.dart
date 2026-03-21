import 'package:flutter/material.dart';

/// Central data source for all 48 emojis used across the 6 games.
/// These emojis match the Express Cards screen exactly.
class GameEmojis {
  GameEmojis._();

  /// All 48 emojis grouped by category.
  static const List<GameEmoji> all = [
    // ── Feelings (12) ──────────────────────────────────────────────
    GameEmoji(emoji: '😊', name: 'Happy', category: 'feelings', color: Color(0xFFFFB088)),
    GameEmoji(emoji: '😢', name: 'Sad', category: 'feelings', color: Color(0xFF74B9FF)),
    GameEmoji(emoji: '😠', name: 'Angry', category: 'feelings', color: Color(0xFFFF6B6B)),
    GameEmoji(emoji: '😨', name: 'Scared', category: 'feelings', color: Color(0xFFBB6BD9)),
    GameEmoji(emoji: '🤩', name: 'Excited', category: 'feelings', color: Color(0xFFFF9F43)),
    GameEmoji(emoji: '😌', name: 'Calm', category: 'feelings', color: Color(0xFF4ECDC4)),
    GameEmoji(emoji: '😴', name: 'Tired', category: 'feelings', color: Color(0xFF636E72)),
    GameEmoji(emoji: '🥰', name: 'Loved', category: 'feelings', color: Color(0xFFFF7EB3)),
    GameEmoji(emoji: '😕', name: 'Confused', category: 'feelings', color: Color(0xFFA29BFE)),
    GameEmoji(emoji: '😎', name: 'Proud', category: 'feelings', color: Color(0xFF7ED957)),
    GameEmoji(emoji: '🙈', name: 'Shy', category: 'feelings', color: Color(0xFFFDAA94)),
    GameEmoji(emoji: '🤪', name: 'Silly', category: 'feelings', color: Color(0xFF00CEC9)),

    // ── Needs (12) ────────────────────────────────────────────────
    GameEmoji(emoji: '🆘', name: 'Help Me', category: 'needs', color: Color(0xFFFFADAD)),
    GameEmoji(emoji: '⏸️', name: 'Break', category: 'needs', color: Color(0xFF74B9FF)),
    GameEmoji(emoji: '🤗', name: 'Hug', category: 'needs', color: Color(0xFFFF7EB3)),
    GameEmoji(emoji: '💧', name: 'Water', category: 'needs', color: Color(0xFFB8D4E3)),
    GameEmoji(emoji: '🍎', name: 'Food', category: 'needs', color: Color(0xFFFF6B6B)),
    GameEmoji(emoji: '🚽', name: 'Toilet', category: 'needs', color: Color(0xFFFDCB6E)),
    GameEmoji(emoji: '🤫', name: 'Quiet', category: 'needs', color: Color(0xFFBB6BD9)),
    GameEmoji(emoji: '🧘', name: 'Space', category: 'needs', color: Color(0xFF55EFC4)),
    GameEmoji(emoji: '🛏️', name: 'Sleep', category: 'needs', color: Color(0xFF636E72)),
    GameEmoji(emoji: '💊', name: 'Medicine', category: 'needs', color: Color(0xFFFF7675)),
    GameEmoji(emoji: '🎧', name: 'Sensory', category: 'needs', color: Color(0xFFA29BFE)),
    GameEmoji(emoji: '🧸', name: 'Comfort', category: 'needs', color: Color(0xFFDEB887)),

    // ── Actions (12) ──────────────────────────────────────────────
    GameEmoji(emoji: '🎮', name: 'Play', category: 'actions', color: Color(0xFF7ED957)),
    GameEmoji(emoji: '🖌️', name: 'Draw', category: 'actions', color: Color(0xFF63CDDA)),
    GameEmoji(emoji: '🎵', name: 'Music', category: 'actions', color: Color(0xFFBB6BD9)),
    GameEmoji(emoji: '🌳', name: 'Outside', category: 'actions', color: Color(0xFF55EFC4)),
    GameEmoji(emoji: '📚', name: 'Read', category: 'actions', color: Color(0xFF74B9FF)),
    GameEmoji(emoji: '📺', name: 'Watch', category: 'actions', color: Color(0xFF636E72)),
    GameEmoji(emoji: '💃', name: 'Dance', category: 'actions', color: Color(0xFFFF7EB3)),
    GameEmoji(emoji: '🧱', name: 'Build', category: 'actions', color: Color(0xFFE17055)),
    GameEmoji(emoji: '🧩', name: 'Puzzle', category: 'actions', color: Color(0xFFFFE66D)),
    GameEmoji(emoji: '👨‍🍳', name: 'Cook', category: 'actions', color: Color(0xFFFDAA94)),
    GameEmoji(emoji: '🤸', name: 'Exercise', category: 'actions', color: Color(0xFF00CEC9)),
    GameEmoji(emoji: '✂️', name: 'Crafts', category: 'actions', color: Color(0xFFA29BFE)),

    // ── Responses (12) ────────────────────────────────────────────
    GameEmoji(emoji: '✅', name: 'Yes', category: 'responses', color: Color(0xFF7ED957)),
    GameEmoji(emoji: '❌', name: 'No', category: 'responses', color: Color(0xFF778BEB)),
    GameEmoji(emoji: '🤔', name: 'Maybe', category: 'responses', color: Color(0xFFFFE66D)),
    GameEmoji(emoji: '➕', name: 'More', category: 'responses', color: Color(0xFF74B9FF)),
    GameEmoji(emoji: '✋', name: 'All Done', category: 'responses', color: Color(0xFFFF9F43)),
    GameEmoji(emoji: '⏳', name: 'Wait', category: 'responses', color: Color(0xFFA29BFE)),
    GameEmoji(emoji: '🔄', name: 'Again', category: 'responses', color: Color(0xFF00CEC9)),
    GameEmoji(emoji: '🛑', name: 'Stop', category: 'responses', color: Color(0xFF786FA6)),
    GameEmoji(emoji: '🙏', name: 'Thank You', category: 'responses', color: Color(0xFFFF7EB3)),
    GameEmoji(emoji: '😔', name: 'Sorry', category: 'responses', color: Color(0xFF636E72)),
    GameEmoji(emoji: '🙂', name: 'Please', category: 'responses', color: Color(0xFF55EFC4)),
    GameEmoji(emoji: '❤️', name: 'I Love You', category: 'responses', color: Color(0xFFF8CD65)),
  ];

  /// Category display info for Emotion Sorting bins.
  static const List<GameEmojiCategory> categories = [
    GameEmojiCategory(
      key: 'feelings',
      name: 'Feelings',
      emoji: '💭',
      color: Color(0xFFFF7EB3),
    ),
    GameEmojiCategory(
      key: 'needs',
      name: 'Needs',
      emoji: '🤲',
      color: Color(0xFF74B9FF),
    ),
    GameEmojiCategory(
      key: 'actions',
      name: 'Actions',
      emoji: '🎯',
      color: Color(0xFF7ED957),
    ),
    GameEmojiCategory(
      key: 'responses',
      name: 'Responses',
      emoji: '💬',
      color: Color(0xFF8B5CF6),
    ),
  ];

  /// Helper: get emojis for a specific category
  static List<GameEmoji> byCategory(String category) =>
      all.where((e) => e.category == category).toList();
}

/// Immutable data class for a single game emoji.
class GameEmoji {
  final String emoji;
  final String name;
  final String category; // 'feelings', 'needs', 'actions', 'responses'
  final Color color;

  const GameEmoji({
    required this.emoji,
    required this.name,
    required this.category,
    required this.color,
  });

  /// Convenience: spelling word (uppercase name)
  String get word => name.toUpperCase();

  /// Convert to Map for backward compatibility with existing game code.
  Map<String, dynamic> toMap() => {
        'emoji': emoji,
        'name': name,
        'color': color,
        'category': category,
      };
}

/// Category display info for sorting games.
class GameEmojiCategory {
  final String key;
  final String name;
  final String emoji;
  final Color color;

  const GameEmojiCategory({
    required this.key,
    required this.name,
    required this.emoji,
    required this.color,
  });
}
