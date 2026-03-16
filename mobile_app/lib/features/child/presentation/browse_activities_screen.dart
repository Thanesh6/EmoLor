import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/activity_item.dart';
import '../services/activity_service.dart';
import '../services/activity_progress_service.dart';
import 'activity_launcher_screen.dart';
import 'continue_restart_dialog.dart';

/// UCD012 – Browse Learning Activities.
/// Displays a child-friendly grid of Games, Drawing, and Stories
/// with category tabs, Adaptive Engine suggestions, and completion badges.
class BrowseActivitiesScreen extends StatefulWidget {
  const BrowseActivitiesScreen({super.key});

  @override
  State<BrowseActivitiesScreen> createState() => _BrowseActivitiesScreenState();
}

class _BrowseActivitiesScreenState extends State<BrowseActivitiesScreen> {
  final ActivityService _service = ActivityService();
  final ActivityProgressService _progressService = ActivityProgressService();

  List<ActivityItem> _allActivities = [];
  Set<String> _inProgressIds = {}; // UCD014: activities with saved progress
  bool _isLoading = true;
  String? _errorMessage;
  ActivityCategory? _selectedCategory; // null = show all

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  // ── Data ──────────────────────────────────────────────────────────────
  Future<void> _loadActivities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var activities = await _service.getAllActivities();
      activities = _service.applyAdaptiveHints(activities);

      // UCD014: determine which activities have saved progress
      final inProgress = await _progressService.allInProgressIds();

      if (mounted) {
        setState(() {
          _allActivities = activities;
          _inProgressIds = inProgress;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Network Error – showing offline activities.';
          _isLoading = false;
          // Alt-flow: offline backup is already returned by service
        });
      }
    }
  }

  List<ActivityItem> get _filtered {
    if (_selectedCategory == null) return _allActivities;
    return _allActivities
        .where((a) => a.category == _selectedCategory)
        .toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────
  TextStyle _cuteText({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w700,
    Color color = Colors.white,
  }) {
    return GoogleFonts.baloo2(
        fontSize: fontSize, fontWeight: fontWeight, color: color);
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF7DD3FC),
              Color(0xFFFDE68A),
              Color(0xFF86EFAC),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              if (_errorMessage != null) _buildErrorBanner(),
              _buildCategoryTabs(),
              const SizedBox(height: 8),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Activities ✨',
            style: _cuteText(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          // Refresh
          GestureDetector(
            onTap: _loadActivities,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  // ── Error banner (alt-flow) ───────────────────────────────────────────
  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD166), width: 2),
      ),
      child: Row(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: _cuteText(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF856404)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Category filter tabs ──────────────────────────────────────────────
  Widget _buildCategoryTabs() {
    final tabs = <_CatTab>[
      const _CatTab(label: 'All', emoji: '🌟', category: null),
      _CatTab(
          label: categoryLabel(ActivityCategory.games),
          emoji: categoryEmoji(ActivityCategory.games),
          category: ActivityCategory.games),
      _CatTab(
          label: categoryLabel(ActivityCategory.drawing),
          emoji: categoryEmoji(ActivityCategory.drawing),
          category: ActivityCategory.drawing),
      _CatTab(
          label: categoryLabel(ActivityCategory.stories),
          emoji: categoryEmoji(ActivityCategory.stories),
          category: ActivityCategory.stories),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = tab.category == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = tab.category),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF8B5CF6) : Colors.white,
                    width: 2.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color:
                                const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tab.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 6),
                    Text(
                      tab.label,
                      style: _cuteText(
                        fontSize: 17,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color:
                            isSelected ? const Color(0xFF6D28D9) : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Grid body ─────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No activities here yet!',
          style: _cuteText(fontSize: 22, color: Colors.white70),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 130,
            mainAxisSpacing: 15,
            crossAxisSpacing: 15,
            mainAxisExtent: 88,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => _buildActivityTile(items[i]),
        );
      },
    );
  }

  // ── Single activity tile ──────────────────────────────────────────────
  Widget _buildActivityTile(ActivityItem item) {
    final colors = item.gradientColors.map((c) => Color(c)).toList();
    final isInProgress = _inProgressIds.contains(item.id);

    return GestureDetector(
      onTap: () => _onActivityTap(item),
      child: Stack(
        children: [
          // Card
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors.length >= 2
                    ? colors
                    : [colors.first, colors.first.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withValues(alpha: 0.45),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.emoji,
                    style: const TextStyle(fontSize: 30, fontFamilyFallback: [
                      'Segoe UI Emoji',
                      'Apple Color Emoji',
                      'Noto Color Emoji'
                    ])),
                const SizedBox(height: 4),
                Text(
                  item.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _cuteText(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  item.description,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _cuteText(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),

          // ── "Suggested" sparkle badge (Adaptive Engine) ─────────────
          if (item.isSuggested)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE68A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 3),
                    Text('For You',
                        style: _cuteText(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF92400E))),
                  ],
                ),
              ),
            ),

          // ── "Completed" badge ────────────────────────────────────────
          if (item.isCompleted)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    color: Color(0xFF22C55E), size: 22),
              ),
            ),

          // ── UCD014: "In-Progress" badge ─────────────────────────────
          if (isInProgress && !item.isCompleted)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pause_circle_filled,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 3),
                    Text('In-Progress',
                        style: _cuteText(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),

          // ── "Played" badge (only when no other top-right badge) ─────
          if (item.lastPlayedAt != null && !item.isCompleted && !isInProgress)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Color(0xFF8B5CF6), size: 20),
              ),
            ),
        ],
      ),
    );
  }

  // ── Navigation on tap ─────────────────────────────────────────────────
  Future<void> _onActivityTap(ActivityItem item) async {
    // UCD014: Check for saved progress
    final savedState = await _progressService.loadProgress(item.id);

    if (savedState != null && mounted) {
      // Show Continue / Restart prompt
      final choice = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ContinueRestartDialog(
          activity: item,
          savedState: savedState,
        ),
      );

      if (!mounted) return;

      if (choice == true) {
        // Continue → launch with saved state
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActivityLauncherScreen(
              activity: item,
              savedState: savedState,
            ),
          ),
        );
      } else if (choice == false) {
        // Restart (Alt-flow 1) → discard saved state, fresh start
        await _progressService.deleteProgress(item.id);
        if (!context.mounted) return;
        await Navigator.push(
          // ignore: use_build_context_synchronously
          context,
          MaterialPageRoute(
            builder: (_) => ActivityLauncherScreen(activity: item),
          ),
        );
      }
      // choice == null → user dismissed dialog, do nothing
    } else {
      // No saved progress → normal UCD013 launcher
      if (!context.mounted) return;
      await Navigator.push(
        // ignore: use_build_context_synchronously
        context,
        MaterialPageRoute(
          builder: (_) => ActivityLauncherScreen(activity: item),
        ),
      );
    }

    // Refresh in-progress badges when returning from activity
    if (mounted) {
      final updated = await _progressService.allInProgressIds();
      setState(() => _inProgressIds = updated);
    }
  }
}

class _CatTab {
  final String label;
  final String emoji;
  final ActivityCategory? category;
  const _CatTab({required this.label, required this.emoji, this.category});
}
