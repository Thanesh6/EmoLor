import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/goal_service.dart';
import 'reward_picker_modal.dart';

/// UCD024 — "New Goal" form dialog.
///
/// Allows a caregiver to:
/// 1. Select a Goal Category (Time Spent, Activity Completion, …)
/// 2. Pick a Target via a roller / wheel widget
/// 3. Choose a Duration (Today / This Week / This Month) — **required**
/// 4. Optionally link a Reward
/// 5. Save — validates that duration is chosen and target > 0
class NewGoalDialog extends StatefulWidget {
  const NewGoalDialog({super.key});

  /// Show the dialog and return `true` if a goal was saved.
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const NewGoalDialog(),
    );
  }

  @override
  State<NewGoalDialog> createState() => _NewGoalDialogState();
}

class _NewGoalDialogState extends State<NewGoalDialog> {
  GoalCategory _selectedCategory = GoalCategory.activityCompletion;

  /// null = user has not yet selected a duration (field is required).
  GoalDuration? _selectedDuration;

  RewardOption? _selectedReward;
  bool _saving = false;
  String? _errorMessage;

  /// Whether to show the red error border on the duration chips.
  bool _durationError = false;

  // ── Roller ──────────────────────────────────────────────────────
  static const int _minTarget = 1;
  static const int _maxTarget = 100;

  int _targetValue = 5;
  late final FixedExtentScrollController _rollerController;

  @override
  void initState() {
    super.initState();
    _rollerController =
        FixedExtentScrollController(initialItem: _targetValue - _minTarget);
  }

  @override
  void dispose() {
    _rollerController.dispose();
    super.dispose();
  }

  // ── Save ────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() {
      _errorMessage = null;
      _durationError = false;
    });

    // Duration is required — user must explicitly pick one.
    if (_selectedDuration == null) {
      setState(() {
        _errorMessage = 'Please select a duration for this goal.';
        _durationError = true;
      });
      return;
    }

    setState(() => _saving = true);

    try {
      await GoalService.createGoal(
        category: _selectedCategory,
        target: _targetValue,
        duration: _selectedDuration!,
        linkedReward: _selectedReward?.title,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                'Goal Set Successfully!',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.of(context).pop(true);
    } on ArgumentError catch (e) {
      setState(() {
        _errorMessage = e.message.toString();
        _saving = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save goal. Please try again.';
        _saving = false;
      });
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────

  TextStyle _poppins({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = Colors.black87,
  }) =>
      GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color);

  String _targetUnit() {
    switch (_selectedCategory) {
      case GoalCategory.timeSpent:
        return 'minutes';
      case GoalCategory.activityCompletion:
        return 'activities';
      case GoalCategory.moodLogging:
        return 'entries';
      case GoalCategory.starCollection:
        return 'stars';
    }
  }

  // ── Reward picker (UCD025) ───────────────────────────────────────

  Future<void> _openRewardPicker() async {
    final picked = await RewardPickerModal.show(
      context,
      currentRewardId: _selectedReward?.id,
    );
    if (picked != null) setState(() => _selectedReward = picked);
  }

  void _clearReward() => setState(() => _selectedReward = null);

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      // clipBehavior clips the gradient to the rounded corners
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 700),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              // Same gradient used in profile_screen.dart
              colors: [Color(0xFFE0F2FE), Color(0xFFF3E8FF)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title bar ─────────────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.flag,
                          color: Color(0xFF6B21A8), size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'New Goal',
                          style: _poppins(
                            size: 22,
                            weight: FontWeight.w700,
                            color: const Color(0xFF6B21A8),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed:
                            _saving ? null : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── 1. Goal Category ──────────────────────────────
                  Text('Goal Category',
                      style: _poppins(size: 18, weight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: GoalCategory.values.map((cat) {
                      final selected = cat == _selectedCategory;
                      return ChoiceChip(
                        label: Text('${cat.emoji}  ${cat.label}'),
                        selected: selected,
                        onSelected: _saving
                            ? null
                            : (_) =>
                                setState(() => _selectedCategory = cat),
                        selectedColor: const Color(0xFFE9D5FF),
                        backgroundColor: Colors.white.withValues(alpha: 0.7),
                        labelStyle: _poppins(
                          size: 13,
                          weight: selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected
                              ? const Color(0xFF6B21A8)
                              : Colors.black87,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: selected
                                ? const Color(0xFF6B21A8)
                                : Colors.grey[300]!,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),

                  // ── 2. Target (roller) ────────────────────────────
                  Text('Target',
                      style: _poppins(size: 18, weight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'Scroll to select the number of ${_targetUnit()}',
                    style: _poppins(size: 13, color: Colors.grey[600]!),
                  ),
                  const SizedBox(height: 12),
                  _buildRoller(),
                  const SizedBox(height: 22),

                  // ── 3. Duration (REQUIRED) ────────────────────────
                  Row(
                    children: [
                      Text('Duration',
                          style:
                              _poppins(size: 18, weight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      Text(
                        '*',
                        style: _poppins(
                          size: 18,
                          weight: FontWeight.w700,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _durationError
                        ? 'Duration is required — please choose a time period'
                        : 'Required — choose a time period',
                    style: _poppins(
                      size: 13,
                      color: _durationError
                          ? Colors.red[700]!
                          : Colors.grey[600]!,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: GoalDuration.values.map((dur) {
                      final selected = dur == _selectedDuration;
                      return ChoiceChip(
                        label: Text(dur.label),
                        selected: selected,
                        onSelected: _saving
                            ? null
                            : (_) => setState(() {
                                  _selectedDuration = dur;
                                  _durationError = false;
                                  // Clear the duration error message if it was set
                                  if (_errorMessage != null &&
                                      _errorMessage!
                                          .contains('duration')) {
                                    _errorMessage = null;
                                  }
                                }),
                        selectedColor: const Color(0xFFE9D5FF),
                        backgroundColor: _durationError
                            ? Colors.red[50]!
                            : Colors.white.withValues(alpha: 0.7),
                        labelStyle: _poppins(
                          size: 13,
                          weight: selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected
                              ? const Color(0xFF6B21A8)
                              : Colors.black87,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: _durationError
                                ? Colors.red[300]!
                                : (selected
                                    ? const Color(0xFF6B21A8)
                                    : Colors.grey[300]!),
                            width: _durationError ? 1.5 : 1.0,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // ── Inline error ──────────────────────────────────
                  if (_errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.red[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style:
                                  _poppins(size: 13, color: Colors.red[700]!),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Save button ───────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B21A8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Save Goal',
                              style: _poppins(
                                size: 16,
                                weight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Roller widget ────────────────────────────────────────────────

  Widget _buildRoller() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6B21A8).withValues(alpha: 0.25),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Centre selection highlight ───────────────────────────
          Positioned(
            left: 0,
            right: 0,
            child: Container(
              height: 46,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE9D5FF),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // ── Wheel ────────────────────────────────────────────────
          ListWheelScrollView.useDelegate(
            controller: _rollerController,
            itemExtent: 46,
            perspective: 0.003,
            diameterRatio: 1.6,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (index) {
              setState(() => _targetValue = _minTarget + index);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: _maxTarget - _minTarget + 1,
              builder: (context, index) {
                final value = _minTarget + index;
                final isSelected = value == _targetValue;
                return Center(
                  child: Text(
                    '$value',
                    style: GoogleFonts.poppins(
                      fontSize: isSelected ? 24 : 17,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: isSelected
                          ? const Color(0xFF6B21A8)
                          : Colors.black45,
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Top fade overlay ─────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFE0F2FE).withValues(alpha: 0.95),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom fade overlay ───────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      const Color(0xFFF3E8FF).withValues(alpha: 0.95),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
