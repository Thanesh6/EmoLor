import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../caregiver/services/goal_service.dart';

/// Shown after profile selection, before "How do you feel today?".
/// Both goal cards sit side-by-side in a single non-scrollable view.
class SetGoalsScreen extends StatefulWidget {
  final String? childName;
  final VoidCallback onContinue;
  final VoidCallback? onBack;

  const SetGoalsScreen({
    super.key,
    this.childName,
    required this.onContinue,
    this.onBack,
  });

  @override
  State<SetGoalsScreen> createState() => _SetGoalsScreenState();
}

class _SetGoalsScreenState extends State<SetGoalsScreen>
    with SingleTickerProviderStateMixin {
  // ── Time goal ────────────────────────────────────────────────────
  bool _timeEnabled = false;
  int _hours = 0;
  int _minutes = 15;
  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minCtrl;

  // ── Star goal ────────────────────────────────────────────────────
  bool _starsEnabled = false;
  // Replaced the old text-input with a wheel-picker (range 1..100).
  static const int _starMin = 1;
  static const int _starMax = 100;
  int _starTargetValue = 10;
  late final FixedExtentScrollController _starCtrl;

  bool _isSaving = false;

  // ── Enter animation ──────────────────────────────────────────────
  late final AnimationController _enterCtrl;
  late final Animation<double> _enterFade;
  late final Animation<Offset> _enterSlide;

  @override
  void initState() {
    super.initState();
    _hourCtrl = FixedExtentScrollController(initialItem: _hours);
    _minCtrl = FixedExtentScrollController(initialItem: _minutes);
    _starCtrl =
        FixedExtentScrollController(initialItem: _starTargetValue - _starMin);

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _enterFade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _enterSlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minCtrl.dispose();
    _starCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  int get _totalMinutes => _hours * 60 + _minutes;
  int get _starTarget => _starTargetValue;
  bool get _hasGoal => _timeEnabled || _starsEnabled;
  bool get _timeValid => !_timeEnabled || _totalMinutes > 0;
  bool get _starValid => !_starsEnabled || _starTarget > 0;
  bool get _canStart => _hasGoal && _timeValid && _starValid;

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      if (_timeEnabled && _totalMinutes > 0) {
        await GoalService.createGoal(
          category: GoalCategory.timeSpent,
          target: _totalMinutes,
          duration: GoalDuration.today,
        );
      }
      if (_starsEnabled && _starTarget > 0) {
        await GoalService.createGoal(
          category: GoalCategory.starCollection,
          target: _starTarget,
          duration: GoalDuration.today,
        );
      }
    } catch (e) {
      debugPrint('SetGoalsScreen._save: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
    if (mounted) widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.childName ?? 'there';
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          // Soft light gradient — same palette as profile_screen.dart
          // and the caregiver "New Goal" dialog so the screen reads as
          // part of the same family.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE0F2FE),
              Color(0xFFF3E8FF),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _enterFade,
            child: SlideTransition(
              position: _enterSlide,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Back button ───────────────────────────────
                  if (widget.onBack != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 0, 0),
                        child: IconButton(
                          onPressed: widget.onBack,
                          icon: const Icon(Icons.arrow_back_ios_rounded,
                              color: Color(0xFF6B21A8)),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 4),

                  // ── Header (moved up, 15% bigger) ─────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Text('🎯',
                            style: const TextStyle(fontSize: 50),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 6),
                        Text(
                          'Set Goals for $name',
                          style: GoogleFonts.fredoka(
                            fontSize: 35,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF6B21A8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Enable at least one goal to continue',
                          style: GoogleFonts.baloo2(
                            fontSize: 16,
                            color: const Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Side-by-side goal cards ───────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildTimeCard()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildStarCard()),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Start button ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: _buildStartButton(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Time Goal Card ────────────────────────────────────────────────

  Widget _buildTimeCard() {
    const color = Color(0xFFF97316);
    return _GoalCard(
      emoji: '⏱️',
      title: 'Time Goal',
      subtitle: 'How long to play?',
      enabled: _timeEnabled,
      color: color,
      onToggle: (v) => setState(() => _timeEnabled = v),
      child: _timeEnabled
          ? Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 14),
                  // Drum-roll pickers (scaled up to fill the card)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildWheelPicker(
                        controller: _hourCtrl,
                        itemCount: 24,
                        label: 'Hours',
                        color: color,
                        onChanged: (i) => setState(() => _hours = i),
                        formatItem: (i) => i.toString().padLeft(2, '0'),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 50),
                        child: Text(
                          ' : ',
                          style: GoogleFonts.baloo2(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                      ),
                      _buildWheelPicker(
                        controller: _minCtrl,
                        itemCount: 60,
                        label: 'Minutes',
                        color: color,
                        onChanged: (i) => setState(() => _minutes = i),
                        formatItem: (i) => i.toString().padLeft(2, '0'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_timeEnabled && _totalMinutes == 0)
                    Text(
                      'Set at least 1 minute',
                      style: GoogleFonts.baloo2(
                          fontSize: 12, color: Colors.red[400]),
                      textAlign: TextAlign.center,
                    ),
                  const Spacer(),
                  Text(
                    '💡 When time is up, you\'ll be asked how you feel before leaving.',
                    style: GoogleFonts.baloo2(
                      fontSize: 15,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildWheelPicker({
    required FixedExtentScrollController controller,
    required int itemCount,
    required String label,
    required Color color,
    required void Function(int) onChanged,
    required String Function(int) formatItem,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.baloo2(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 100,
          height: 220,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.28), width: 1.5),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Centre highlight stripe
              Container(
                height: 56,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              ListWheelScrollView.useDelegate(
                controller: controller,
                itemExtent: 56,
                diameterRatio: 1.4,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: onChanged,
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: itemCount,
                  builder: (context, index) => Center(
                    child: Text(
                      formatItem(index),
                      style: GoogleFonts.baloo2(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Star Goal Card ────────────────────────────────────────────────

  Widget _buildStarCard() {
    const color = Color(0xFFF59E0B);
    return _GoalCard(
      emoji: '⭐',
      title: 'Stars Goal',
      subtitle: 'How many stars?',
      enabled: _starsEnabled,
      color: color,
      onToggle: (v) => setState(() => _starsEnabled = v),
      child: _starsEnabled
          ? Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 14),
                  // Wheel picker — replaces the keyboard-based input.
                  // Children pick a number by scrolling, just like the
                  // hours / minutes pickers on the Time card.
                  _buildWheelPicker(
                    controller: _starCtrl,
                    itemCount: _starMax - _starMin + 1,
                    label: 'Stars',
                    color: color,
                    onChanged: (i) =>
                        setState(() => _starTargetValue = _starMin + i),
                    formatItem: (i) => (_starMin + i).toString(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'stars ⭐',
                    style: GoogleFonts.baloo2(
                      fontSize: 20,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '✅ You can keep playing after reaching the star goal.',
                    style: GoogleFonts.baloo2(
                      fontSize: 15,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  // ── Start button ──────────────────────────────────────────────────

  Widget _buildStartButton() {
    return Column(
      children: [
        // Narrower, centered start button (not full-width)
        SizedBox(
          width: 320,
          child: ElevatedButton(
            onPressed: (_isSaving || !_canStart) ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: _canStart
                  ? const Color(0xFF10B981)
                  : const Color(0xFFD1D5DB),
              disabledBackgroundColor: const Color(0xFFD1D5DB),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              elevation: _canStart ? 6 : 0,
              shadowColor: _canStart
                  ? const Color(0xFF10B981).withValues(alpha: 0.5)
                  : null,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Text(
                    "Let's Start! 🚀",
                    style: GoogleFonts.fredoka(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        if (!_hasGoal) ...[
          const SizedBox(height: 8),
          Text(
            'Please enable at least one goal to continue',
            style: GoogleFonts.baloo2(
              fontSize: 12,
              color: const Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

// ── Reusable card shell ───────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool enabled;
  final Color color;
  final ValueChanged<bool> onToggle;
  final Widget child;

  const _GoalCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.color,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: enabled ? color : Colors.transparent,
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: enabled
                ? color.withValues(alpha: 0.22)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      // Column fills full card height so inner Expanded widgets work.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header row
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.baloo2(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.baloo2(
                        fontSize: 14,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onToggle,
                activeColor: color,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          // Picker / input area
          child,
        ],
      ),
    );
  }
}
