import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/star_service.dart';
import '../features/child/services/child_rewards_service.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen>
    with TickerProviderStateMixin {
  static const int _upcomingPageSize = 4;

  late AnimationController _pulseController;
  List<ChildReward> _rewards = [];
  int _totalStars = 0;
  bool _isLoading = true;
  int _upcomingPageStart = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    StarService.setGameStars(StarService.emotionPath, 3)
        .then((_) => _loadData());
  }

  Future<void> _loadData() async {
    final rewards = await ChildRewardsService.getAllRewards();
    final total = await StarService.getTotalStars();
    if (mounted) {
      setState(() {
        rewards.sort((a, b) {
          final aCost = a.milestoneStars ?? a.starCost ?? 999;
          final bCost = b.milestoneStars ?? b.starCost ?? 999;
          return aCost.compareTo(bCost);
        });
        _rewards = rewards;
        _totalStars = total;
        _isLoading = false;
        _upcomingPageStart = 0;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // Split rewards into unlocked, next, and upcoming
  ChildReward? get _nextReward {
    final locked = _rewards.where((r) => !r.isUnlocked).toList();
    return locked.isEmpty ? null : locked.first;
  }

  List<ChildReward> get _upcomingRewards {
    final locked = _rewards.where((r) => !r.isUnlocked).toList();
    return locked.length > 1 ? locked.sublist(1) : [];
  }

  List<ChildReward> get _unlockedRewards {
    return _rewards.where((r) => r.isUnlocked).toList();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: GoogleFonts.baloo2(fontSize: 18, color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: const Color(0xFF8B5CF6),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFADBE8),
              Color(0xFFE7D7FF),
              Color(0xFFD9ECFF),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFF8B5CF6)))
                    : _rewards.isEmpty
                        ? _buildEmptyState()
                        : _buildMainContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Color(0xFF6B21A8), size: 31),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'My Rewards',
                  style: GoogleFonts.baloo2(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1B2541),
                    shadows: const [
                      Shadow(
                          offset: Offset(2, 2),
                          blurRadius: 6,
                          color: Color(0x33000000)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text('🏆', style: TextStyle(fontSize: 36)),
              ],
            ),
          ),
          // Star count pill
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) => Transform.scale(
              scale: 1.0 + (_pulseController.value * 0.04),
              child: child,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⭐', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 8),
                  Text(
                    '$_totalStars ${_totalStars <= 1 ? 'Star' : 'Stars'}',
                    style: GoogleFonts.baloo2(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Main content: left (next reward + up next) + right (earned) ──

  Widget _buildMainContent() {
    final next = _nextReward;
    final upcoming = _upcomingRewards;
    final unlocked = _unlockedRewards;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── LEFT: Next Reward + Up Next below ──
          Expanded(
            flex: 5,
            child: Column(
              children: [
                Expanded(
                  child: next != null
                      ? _buildFeaturedRewardCard(next)
                      : _buildAllUnlockedCard(),
                ),
                if (upcoming.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Expanded(child: _buildUpcomingSection(upcoming)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          // ── RIGHT: Earned single frame ──
          Expanded(
            flex: 4,
            child: unlocked.isEmpty
                ? const SizedBox.shrink()
                : _buildEarnedSection(unlocked),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingSection(List<ChildReward> upcoming) {
    final maxPageStart = upcoming.isEmpty
        ? 0
        : ((upcoming.length - 1) ~/ _upcomingPageSize) * _upcomingPageSize;
    final pageStart =
        _upcomingPageStart > maxPageStart ? maxPageStart : _upcomingPageStart;
    final visibleRewards =
        upcoming.skip(pageStart).take(_upcomingPageSize).toList();
    final showReturn = pageStart > 0;
    final showMore = pageStart + _upcomingPageSize < upcoming.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const tileGap = 18.0;

          return Column(
            children: [
              _buildSectionHeader(
                '📋',
                'Up Next',
                const Color(0xFF6B21A8),
                bgColor: const Color(0xFFDDEEFF),
                fontSize: 26,
                emojiSize: 20,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: showReturn ? 70 : 16,
                        child: showReturn
                            ? _buildReturnArrowTile()
                            : const SizedBox(),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (int i = 0;
                                i < visibleRewards.length;
                                i++) ...[
                              Flexible(
                                child: _buildUpcomingHorizontalTile(visibleRewards[i]),
                              ),
                              if (i != visibleRewards.length - 1)
                                const SizedBox(width: tileGap),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 70,
                        child: showMore
                            ? Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: _buildMoreArrowTile(),
                              )
                            : const SizedBox(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String emoji, String label, Color color,
      {Color bgColor = Colors.white,
      double fontSize = 20,
      double emojiSize = 18}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: emojiSize)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.baloo2(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Featured "Next Reward" card (big, left side) ──────────────────

  Widget _buildFeaturedRewardCard(ChildReward reward) {
    final rewardColor = Color(reward.colorValue);
    final starsNeeded = reward.milestoneStars ?? reward.starCost ?? 0;
    final progress =
        starsNeeded > 0 ? (_totalStars / starsNeeded).clamp(0.0, 1.0) : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: rewardColor.withValues(alpha: 0.3),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: rewardColor.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 420;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                SizedBox(height: compact ? 18 : 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) => Transform.scale(
                            scale: 1.0 + (_pulseController.value * 0.05),
                            child: child,
                          ),
                          child: Container(
                            width: compact ? 203 : 223,
                            height: compact ? 203 : 223,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  rewardColor.withValues(alpha: 0.32),
                                  rewardColor.withValues(alpha: 0.12),
                                ],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: rewardColor.withValues(alpha: 0.45),
                                width: 4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: rewardColor.withValues(alpha: 0.20),
                                  blurRadius: 16,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                reward.emoji,
                                style: TextStyle(fontSize: compact ? 103 : 113),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              '🎯 Next Reward',
                              style: GoogleFonts.baloo2(
                                fontSize: compact ? 26 : 27,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF7C3AED),
                              ),
                            ),
                          ),
                          SizedBox(height: compact ? 10 : 12),
                          Text(
                            reward.title,
                            style: GoogleFonts.baloo2(
                              fontSize: compact ? 36 : 40,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF1F2937),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            reward.description,
                            style: GoogleFonts.baloo2(
                              fontSize: compact ? 20 : 22,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF111827),
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: compact ? 12 : 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: compact ? 18 : 21,
                              backgroundColor: const Color(0xFFF3F4F6),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  rewardColor.withValues(alpha: 0.7)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '$_totalStars / $starsNeeded ⭐',
                              style: GoogleFonts.baloo2(
                                fontSize: compact ? 22 : 24,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF374151),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 12 : 16),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── "All unlocked" card (when no more locked rewards) ─────────────

  Widget _buildAllUnlockedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          Text(
            'All Rewards Unlocked!',
            style: GoogleFonts.baloo2(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF059669),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'You\'re amazing! You got them all! 🌟',
            style: GoogleFonts.baloo2(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Earned section ────────────────────────────────────────────────

  Widget _buildEarnedSection(List<ChildReward> unlocked) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.28),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              _buildSectionHeader(
                '🏅',
                'Earned (${unlocked.length})',
                const Color(0xFF059669),
                bgColor: const Color(0xFFD1FAE5),
                fontSize: 31,
                emojiSize: 29,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.94,
                  ),
                  itemCount: unlocked.length,
                  itemBuilder: (_, i) => _buildUnlockedCircleTile(unlocked[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUnlockedCircleTile(ChildReward reward) {
    final rewardColor = Color(reward.colorValue);

    return GestureDetector(
      onTap: () => _showRewardDetail(reward),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.96,
          heightFactor: 0.96,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: rewardColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: rewardColor.withValues(alpha: 0.28),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 134,
                  height: 134,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        rewardColor.withValues(alpha: 0.82),
                        rewardColor.withValues(alpha: 0.45),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: rewardColor.withValues(alpha: 0.16),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      reward.emoji,
                      style: const TextStyle(fontSize: 86),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  reward.title,
                  style: GoogleFonts.baloo2(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2937),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreArrowTile() {
    return SizedBox(
      width: 70,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 34),
          TextButton(
            onPressed: () {
              setState(() {
                final maxStart = _upcomingRewards.isEmpty
                    ? 0
                    : ((_upcomingRewards.length - 1) ~/ _upcomingPageSize) *
                        _upcomingPageSize;
                final nextStart = _upcomingPageStart + _upcomingPageSize;
                _upcomingPageStart =
                    nextStart > maxStart ? maxStart : nextStart;
              });
            },
            style: TextButton.styleFrom(
              minimumSize: const Size(54, 54),
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
              backgroundColor: const Color(0xFFE8EEF8),
              side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
            ),
            child: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF6B7280),
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'More',
            style: GoogleFonts.baloo2(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnArrowTile() {
    return SizedBox(
      width: 70,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 34),
          TextButton(
            onPressed: () {
              setState(() {
                _upcomingPageStart = 0;
              });
            },
            style: TextButton.styleFrom(
              minimumSize: const Size(54, 54),
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
              backgroundColor: const Color(0xFFEAF4FF),
              side: const BorderSide(color: Color(0xFFD5E6FB), width: 1.5),
            ),
            child: const Icon(
              Icons.chevron_left_rounded,
              color: Color(0xFF4B5563),
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Return',
            style: GoogleFonts.baloo2(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingHorizontalTile(ChildReward reward) {
    final starsNeeded = reward.milestoneStars ?? reward.starCost ?? 0;

    return GestureDetector(
      onTap: () => _showRewardDetail(reward),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFAFF),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF5EFFF), Color(0xFFE7F2FF)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(reward.emoji,
                        style: const TextStyle(fontSize: 45)),
                  ),
                ),
                Positioned(
                  right: 3,
                  bottom: 2,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Center(
                      child: Text('🔒', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              reward.title,
              style: GoogleFonts.baloo2(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF374151),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$starsNeeded ⭐',
                style: GoogleFonts.baloo2(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFB45309),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 24),
          Text(
            'Your trophy shelf is empty!',
            style: GoogleFonts.baloo2(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF6B21A8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Play some games to earn stars! 🎮✨',
            style: GoogleFonts.baloo2(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  // ── Detail popup ──────────────────────────────────────────────────

  void _showRewardDetail(ChildReward reward) {
    final rewardColor = Color(reward.colorValue);
    final starsNeeded = reward.milestoneStars ?? reward.starCost ?? 0;
    final canAfford = _totalStars >= starsNeeded;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  reward.isUnlocked
                      ? rewardColor.withValues(alpha: 0.08)
                      : const Color(0xFFF9FAFB),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: reward.isUnlocked
                    ? rewardColor.withValues(alpha: 0.35)
                    : const Color(0xFFE5E7EB),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    gradient: reward.isUnlocked
                        ? LinearGradient(colors: [
                            rewardColor,
                            rewardColor.withValues(alpha: 0.6)
                          ])
                        : const LinearGradient(
                            colors: [Color(0xFFF3F4F6), Color(0xFFE5E7EB)]),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: reward.isUnlocked
                            ? Colors.white
                            : const Color(0xFFD1D5DB),
                        width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: reward.isUnlocked
                            ? rewardColor.withValues(alpha: 0.3)
                            : Colors.grey.withValues(alpha: 0.15),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      reward.isUnlocked ? reward.emoji : '🔒',
                      style: TextStyle(fontSize: reward.isUnlocked ? 54 : 44),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  reward.title,
                  style: GoogleFonts.baloo2(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF6D28D9),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  reward.description,
                  style: GoogleFonts.baloo2(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                if (reward.isUnlocked) ...[
                  if (reward.type == RewardType.theme ||
                      reward.type == RewardType.treasure)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: reward.isEquipped
                            ? () async {
                                await ChildRewardsService.unequipReward();
                                await _loadData();
                                if (ctx.mounted) Navigator.pop(ctx);
                                _showSnackBar('${reward.emoji} Unequipped!');
                              }
                            : () async {
                                await ChildRewardsService.equipReward(
                                    reward.id);
                                await _loadData();
                                if (ctx.mounted) Navigator.pop(ctx);
                                _showSnackBar(
                                    '${reward.emoji} ${reward.title} equipped!');
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: reward.isEquipped
                              ? const Color(0xFFE5E7EB)
                              : rewardColor,
                          foregroundColor: reward.isEquipped
                              ? const Color(0xFF6B7280)
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          reward.isEquipped ? '✓ Equipped' : '✨ Use This!',
                          style: GoogleFonts.baloo2(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  if (reward.type == RewardType.badge)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🏅', style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 8),
                          Text(
                            'Badge Unlocked!',
                            style: GoogleFonts.baloo2(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                if (!reward.isUnlocked) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: LinearProgressIndicator(
                      value: starsNeeded > 0
                          ? (_totalStars / starsNeeded).clamp(0.0, 1.0)
                          : 0,
                      minHeight: 14,
                      backgroundColor: const Color(0xFFF3F4F6),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        canAfford
                            ? const Color(0xFF10B981)
                            : rewardColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$_totalStars / $starsNeeded ⭐',
                    style: GoogleFonts.baloo2(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!canAfford)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8B4FE),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFC084FC)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🔒', style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 8),
                          Text(
                            'Need ${starsNeeded - _totalStars} more stars',
                            style: GoogleFonts.baloo2(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF4C1D95),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Close',
                    style: GoogleFonts.baloo2(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
