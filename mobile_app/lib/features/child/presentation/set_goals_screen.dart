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
  final TextEditingController _starCtrl = TextEditingController(text: '10');

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
  int get _starTarget => int.tryParse(_starCtrl.text) ?? 0;
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6B21A8),
              Color(0xFF1D4ED8),
              Color(0xFF0E7490),
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
                        padding: const EdgeInsets.fromLTRB(8, 8, 0, 0),
                        child: IconButton(
                          onPressed: widget.onBack,
                          icon: const Icon(Icons.arrow_back_ios_rounded,
                              color: Colors.white70),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 12),

                  // ── Header ────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Text('🎯',
                            style: const TextStyle(fontSize: 44),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 6),
                        Text(
                          'Set Goals for $name',
                          style: GoogleFonts.fredoka(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            shadows: const [
                              Shadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                  offset: Offset(0, 2))
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Enable at least one goal to continue',
                          style: GoogleFonts.baloo2(
                            fontSize: 14,
                            color: Colors.white60,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

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
                  const SizedBox(height: 10),
                  // Drum-roll pickers
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
                        padding: const EdgeInsets.only(bottom: 36),
                        child: Text(
                          ' : ',
                          style: GoogleFonts.baloo2(
                            fontSize: 28,
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
                  const SizedBox(height: 8),
                  if (_timeEnabled && _totalMinutes == 0)
                    Text(
                      'Set at least 1 minute',
                      style: GoogleFonts.baloo2(
                          fontSize: 11, color: Colors.red[400]),
                      textAlign: TextAlign.center,
                    ),
                  const Spacer(),
                  Text(
                    '💡 When time is up, you\'ll be asked how you feel before leaving.',
                    style: GoogleFonts.baloo2(
                      fontSize: 11,
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
            fontSize: 12,
            color: Colors.grey[500],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 64,
          height: 130,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Centre highlight stripe
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              ListWheelScrollView.useDelegate(
                controller: controller,
                itemExtent: 40,
                diameterRatio: 1.4,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: onChanged,
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: itemCount,
                  builder: (context, index) => Center(
                    child: Text(
                      formatItem(index),
                      style: GoogleFonts.baloo2(
                        fontSize: 22,
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
                  const SizedBox(height: 12),
                  // Big number input
                  Container(
                    width: 140,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: color.withValues(alpha: 0.3), width: 2),
                    ),
                    child: TextField(
                      controller: _starCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 8),
                        hintText: '10',
                        hintStyle: GoogleFonts.baloo2(
                          fontSize: 36,
                          color: color.withValues(alpha: 0.35),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'stars ⭐',
                    style: GoogleFonts.baloo2(
                      fontSize: 16,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_starsEnabled && _starTarget <= 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Enter a number above 0',
                      style: GoogleFonts.baloo2(
                          fontSize: 11, color: Colors.red[400]),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '✅ You can keep playing after reaching the star goal.',
                    style: GoogleFonts.baloo2(
                      fontSize: 11,
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
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_isSaving || !_canStart) ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: _canStart
                  ? const Color(0xFF10B981)
                  : Colors.white.withValues(alpha: 0.18),
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.18),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white38,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
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
              color: Colors.white54,
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
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.baloo2(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.baloo2(
                        fontSize: 11,
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
