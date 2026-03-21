import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/data/game_emojis.dart';
import '../core/services/star_service.dart';
import '../core/widgets/star_reward_widget.dart';
import '../features/child/presentation/help_button.dart';
import '../features/child/presentation/activity_exit_handler.dart';
import '../features/child/presentation/completion_feedback_overlay.dart';
import '../features/child/models/activity_save_state.dart';
import '../features/child/services/activity_progress_service.dart';

/// Emotion Sorting — Children drag emoji faces into the correct
/// category boxes (Feelings, Needs, Actions, Responses).
class EmotionSortingScreen extends StatefulWidget {
  const EmotionSortingScreen({super.key});

  @override
  State<EmotionSortingScreen> createState() => _EmotionSortingScreenState();
}

class _EmotionSortingScreenState extends State<EmotionSortingScreen>
    with TickerProviderStateMixin {
  static const String _activityId = 'game_emotion_sorting';
  final ActivityProgressService _progressService = ActivityProgressService();

  // Categories from Express Cards (Feelings, Needs, Actions, Responses)
  static final List<Map<String, dynamic>> _categories =
      GameEmojis.categories.map((c) => {
        'name': c.name,
        'emoji': c.emoji,
        'color': c.color,
        'key': c.key,
      }).toList();

  // All 48 emoji items to sort, each tagged with its category
  static final List<Map<String, String>> _allItems =
      GameEmojis.all.map((e) => {
        'emoji': e.emoji,
        'category': e.category == 'feelings' ? 'Feelings'
            : e.category == 'needs' ? 'Needs'
            : e.category == 'actions' ? 'Actions'
            : 'Responses',
      }).toList();

  final Random _rng = Random();

  // Current round: pick a subset of items to sort
  static const int _itemsPerRound = 6;
  static const int _totalRounds = 8;
  int _currentRound = 0;
  int _stars = 0;
  int _sortedCorrectly = 0;

  late List<Map<String, String>> _currentItems; // items to sort this round
  late List<bool> _itemSorted; // whether each item has been sorted
  String? _hoveredCategory;
  bool _showRoundComplete = false;
  bool _showWrongFeedback = false;

  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _setupRound();
    _restoreProgress();
  }

  Future<void> _restoreProgress() async {
    final saved = await _progressService.loadProgress(_activityId);
    if (!mounted || saved == null) return;

    final data = saved.progressData;
    final savedRound = data['currentRound'];
    final savedStars = data['stars'];
    final savedCorrectly = data['sortedCorrectly'];
    final savedItemsRaw = data['currentItems'];
    final savedSortedRaw = data['itemSorted'];

    if (savedRound is! int ||
        savedStars is! int ||
        savedCorrectly is! int ||
        savedItemsRaw is! List ||
        savedSortedRaw is! List) {
      return;
    }

    // Parse the lists
    try {
      final parsedItems = savedItemsRaw.map<Map<String, String>>((item) {
        final map = item as Map;
        return {
          'emoji': map['emoji'] as String,
          'category': map['category'] as String,
        };
      }).toList();

      final parsedSorted = savedSortedRaw.map<bool>((b) => b as bool).toList();

      if (parsedItems.length == _itemsPerRound &&
          parsedSorted.length == _itemsPerRound) {
        setState(() {
          _currentRound = savedRound;
          _stars = savedStars;
          _sortedCorrectly = savedCorrectly;
          _currentItems = parsedItems;
          _itemSorted = parsedSorted;
          _showRoundComplete = false;
          _showWrongFeedback = false;
          _hoveredCategory = null;
        });
      }
    } catch (_) {
      // Ignore parasing errors
    }
  }

  Map<String, dynamic> _buildProgressData() {
    return {
      'currentRound': _currentRound,
      'stars': _stars,
      'sortedCorrectly': _sortedCorrectly,
      'currentItems': _currentItems,
      'itemSorted': _itemSorted,
    };
  }

  Future<void> _saveProgress() async {
    await _progressService.saveProgress(
      ActivitySaveState(
        activityId: _activityId,
        savedAt: DateTime.now(),
        elapsedSeconds: 0,
        progressData: _buildProgressData(),
      ),
    );
  }

  Future<void> _handleReturnPressed() async {
    await ActivityExitHandler.handleExitActivity(
      context: context,
      activityId: _activityId,
      activityEmoji: '📋',
      buildProgressData: _buildProgressData,
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _setupRound() {
    _showRoundComplete = false;
    _showWrongFeedback = false;
    _hoveredCategory = null;

    // Pick _itemsPerRound random items ensuring at least 2 categories
    final shuffled = List<Map<String, String>>.from(_allItems)..shuffle(_rng);
    _currentItems = shuffled.take(_itemsPerRound).toList();

    // Ensure at least 2 different categories
    final cats = _currentItems.map((e) => e['category']).toSet();
    if (cats.length < 2) {
      // Replace last item with one from a different category
      final otherCat = _categories.firstWhere((c) => c['name'] != cats.first);
      final replacement =
          _allItems.firstWhere((e) => e['category'] == otherCat['name']);
      _currentItems[_currentItems.length - 1] = replacement;
    }

    _currentItems.shuffle(_rng);
    _itemSorted = List.filled(_currentItems.length, false);
    setState(() {});
  }

  void _onItemDropped(int itemIndex, String categoryName) {
    final item = _currentItems[itemIndex];
    if (item['category'] == categoryName) {
      // Correct!
      setState(() {
        _itemSorted[itemIndex] = true;
        _sortedCorrectly++;
        _hoveredCategory = null;
      });

      // Check if all sorted
      if (_itemSorted.every((s) => s)) {
        _onRoundComplete();
      }
    } else {
      // Wrong — shake
      setState(() {
        _showWrongFeedback = true;
        _hoveredCategory = null;
      });
      _shakeController.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _showWrongFeedback = false);
      });
    }
  }

  void _onRoundComplete() {
    setState(() => _showRoundComplete = true);
    StarService.addStars(StarService.colorMemory, 1);
    _stars++;

    Future.delayed(const Duration(milliseconds: 1200), () async {
      if (!mounted) return;
      if (_currentRound + 1 >= _totalRounds) {
        await _progressService.deleteProgress(_activityId);
        if (!mounted) return;
        CompletionFeedbackOverlay.show(
          context: context,
          activityId: _activityId,
          activityName: 'Emotion Sorting',
          starGameKey: StarService.colorMemory,
          starsEarned: 3,
          scoreValue: _stars,
          scoreMax: _totalRounds,
          onPlayAgain: () {
            setState(() {
              _currentRound = 0;
              _stars = 0;
              _sortedCorrectly = 0;
            });
            _setupRound();
          },
        );
      } else {
        if (!mounted) return;
        StarRewardWidget.show(context);
        setState(() => _currentRound++);
        _setupRound();
        await _saveProgress();
      }
    });
  }

  TextStyle _cute(
          {double sz = 24,
          Color c = Colors.white,
          FontWeight fw = FontWeight.w700}) =>
      GoogleFonts.baloo2(fontSize: sz, fontWeight: fw, color: c);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _handleReturnPressed();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7), Color(0xFFECFDF5)],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    // Moved down by ~20%
                    const SizedBox(height: 130),
                    // Emoji items to sort (unsorted ones)
                    SizedBox(
                      height: 130, // Increased height to fit +20% size
                      child: _buildItemsTray(),
                    ),
                    const SizedBox(height: 20),
                    // Category drop zones
                    Expanded(
                      child: _buildCategoryBoxes(),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
                // Back button (matched to Emoji Puzzle)
                Positioned(
                  top: 10,
                  left: 10,
                  child: GestureDetector(
                    onTap: _handleReturnPressed,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 32),
                    ),
                  ),
                ),
                // Banner (matched to Emoji Puzzle)
                Positioned(
                  top: 14,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 31),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(31),
                        border: Border.all(
                          color: const Color(0xFFBB6BD9).withValues(alpha: 0.5),
                          width: 3,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('📋 Sort: ',
                              style: _cute(
                                  sz: 29,
                                  fw: FontWeight.w900,
                                  c: Colors.black87)),
                          Text('${_currentRound + 1}/$_totalRounds',
                              style: _cute(sz: 38, c: const Color(0xFFBB6BD9))),
                        ],
                      ),
                    ),
                  ),
                ),
                // Hint + Stars (matched to Emoji Puzzle)
                Positioned(
                  top: 14,
                  right: 16,
                  child: Row(
                    children: [
                      const HelpButton(
                        activityId: 'game_emotion_sorting',
                        activityEmoji: '📋',
                        activityName: 'Emotion Sorting',
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 19, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B21A8),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Text('⭐ $_stars', style: _cute(sz: 26)),
                      ),
                    ],
                  ),
                ),
                // Round complete
                if (_showRoundComplete)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(36),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 20),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🎉', style: TextStyle(fontSize: 60)),
                          const SizedBox(height: 12),
                          Text('All Sorted!',
                              style: _cute(
                                  sz: 32,
                                  fw: FontWeight.w900,
                                  c: const Color(0xFF22C55E))),
                        ],
                      ),
                    ),
                  ),
                // Wrong feedback
                if (_showWrongFeedback)
                  Positioned(
                    bottom: 200,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('🤔 Try another box!',
                            style: _cute(sz: 22, fw: FontWeight.w700)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemsTray() {
    final unsorted = <int>[];
    for (int i = 0; i < _currentItems.length; i++) {
      if (!_itemSorted[i]) unsorted.add(i);
    }

    if (unsorted.isEmpty) return const SizedBox.shrink();

    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: unsorted.map((itemIndex) {
            final item = _currentItems[itemIndex];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Draggable<int>(
                data: itemIndex,
                feedback: Material(
                  color: Colors.transparent,
                  // +15% size: 117 -> 134
                  child: _buildEmojiTile(item['emoji']!, 134, true),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  // +15% size: 104 -> 119
                  child: _buildEmojiTile(item['emoji']!, 119, false),
                ),
                // +15% size: 104 -> 119
                child: _buildEmojiTile(item['emoji']!, 119, false),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmojiTile(String emoji, double size, bool isDragging) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDragging
              ? const Color(0xFFBB6BD9)
              : const Color(0xFFBB6BD9).withValues(alpha: 0.4),
          width: isDragging ? 3.5 : 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDragging
                ? const Color(0xFFBB6BD9).withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: isDragging ? 14 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(emoji, style: TextStyle(fontSize: size * 0.55)),
      ),
    );
  }

  Widget _buildCategoryBoxes() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: _categories.map((cat) {
          final name = cat['name'] as String;
          final emoji = cat['emoji'] as String;
          final color = cat['color'] as Color;
          final isHovered = _hoveredCategory == name;

          // Count how many items of this category have been sorted
          int sortedCount = 0;
          for (int i = 0; i < _currentItems.length; i++) {
            if (_itemSorted[i] && _currentItems[i]['category'] == name) {
              sortedCount++;
            }
          }
          // Total items of this category in current round
          final totalForCat =
              _currentItems.where((e) => e['category'] == name).length;

          return Expanded(
            child: Padding(
              // Box width reduced by ~10% by increasing padding from 2 to 12
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DragTarget<int>(
                onWillAcceptWithDetails: (details) {
                  setState(() => _hoveredCategory = name);
                  return true;
                },
                onLeave: (_) => setState(() => _hoveredCategory = null),
                onAcceptWithDetails: (details) =>
                    _onItemDropped(details.data, name),
                builder: (context, candidateData, rejectedData) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isHovered
                          ? color.withValues(alpha: 0.25)
                          : color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isHovered ? color : color.withValues(alpha: 0.4),
                        width: isHovered ? 4 : 2.5,
                      ),
                      boxShadow: isHovered
                          ? [
                              BoxShadow(
                                  color: color.withValues(alpha: 0.3),
                                  blurRadius: 14)
                            ]
                          : [],
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        // Increase height by another 30% (286 -> 371)
                        constraints: const BoxConstraints(minHeight: 371),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Emoji and Text bigger by another 25%
                            Text(emoji, style: const TextStyle(fontSize: 138)),
                            const SizedBox(height: 12),
                            Text(name,
                                // Black color for all category names
                                style: _cute(
                                    sz: 55,
                                    fw: FontWeight.w900,
                                    c: Colors.black)),
                            const SizedBox(height: 6),
                            // Show sorted emojis
                            if (sortedCount > 0)
                              SizedBox(
                                width:
                                    140, // constrain wrap width inside FittedBox
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 2,
                                  children: _currentItems
                                      .asMap()
                                      .entries
                                      .where((e) =>
                                          _itemSorted[e.key] &&
                                          e.value['category'] == name)
                                      .map((e) => Text(e.value['emoji']!,
                                          style: const TextStyle(fontSize: 38)))
                                      .toList(),
                                ),
                              ),
                            if (sortedCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('$sortedCount/$totalForCat',
                                    style: _cute(
                                        sz: 18,
                                        c: color.withValues(alpha: 0.7))),
                              ),
                            if (isHovered)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Icon(Icons.arrow_downward_rounded,
                                    color: color, size: 28),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
