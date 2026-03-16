import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/goal_service.dart';
import 'reward_picker_modal.dart';

/// UCD024 — "New Goal" form dialog.
///
/// Allows a caregiver to:
/// 1. Select a Goal Category (Time Spent, Activity Completion, …)
/// 2. Define a Target (numeric)
/// 3. Choose a Duration (Today / This Week / This Month)
/// 4. Optionally link a Reward
/// 5. Save — validates that target > 0
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
  final _formKey = GlobalKey<FormState>();
  final _targetController = TextEditingController(text: '');

  GoalCategory _selectedCategory = GoalCategory.activityCompletion;
  GoalDuration _selectedDuration = GoalDuration.thisWeek;
  RewardOption? _selectedReward;
  bool _saving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  // ── Save ────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    final target = int.tryParse(_targetController.text.trim()) ?? 0;
    if (target <= 0) {
      setState(() => _errorMessage = 'Please set a valid target number.');
      return;
    }

    setState(() => _saving = true);

    try {
      await GoalService.createGoal(
        category: _selectedCategory,
        target: target,
        duration: _selectedDuration,
        linkedReward: _selectedReward?.title,
      );

      if (!mounted) return;

      // Show success snackbar
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
  }) {
    return GoogleFonts.poppins(
        fontSize: size, fontWeight: weight, color: color);
  }

  String _targetHint() {
    switch (_selectedCategory) {
      case GoalCategory.timeSpent:
        return 'e.g. 15 (minutes)';
      case GoalCategory.activityCompletion:
        return 'e.g. 3 (activities)';
      case GoalCategory.moodLogging:
        return 'e.g. 5 (entries)';
      case GoalCategory.starCollection:
        return 'e.g. 20 (stars)';
    }
  }

  // ── Reward picker (UCD025) ───────────────────────────────────────

  Future<void> _openRewardPicker() async {
    final picked = await RewardPickerModal.show(
      context,
      currentRewardId: _selectedReward?.id,
    );
    if (picked != null) {
      setState(() => _selectedReward = picked);
    }
  }

  void _clearReward() {
    setState(() => _selectedReward = null);
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
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
                      style: _poppins(size: 14, weight: FontWeight.w600)),
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
                            : (_) => setState(() => _selectedCategory = cat),
                        selectedColor: const Color(0xFFE9D5FF),
                        backgroundColor: Colors.grey[100],
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

                  // ── 2. Target ──────────────────────────────────────
                  Text('Target',
                      style: _poppins(size: 14, weight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _targetController,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: _targetHint(),
                      hintStyle: _poppins(size: 14, color: Colors.grey[400]!),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF6B21A8), width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                    ),
                    style: _poppins(size: 15),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please set a valid target number.';
                      }
                      final n = int.tryParse(val.trim());
                      if (n == null || n <= 0) {
                        return 'Please set a valid target number.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 22),

                  // ── 3. Duration ────────────────────────────────────
                  Text('Duration',
                      style: _poppins(size: 14, weight: FontWeight.w600)),
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
                            : (_) => setState(() => _selectedDuration = dur),
                        selectedColor: const Color(0xFFE9D5FF),
                        backgroundColor: Colors.grey[100],
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

                  // ── 4. Linked Reward (optional — UCD025) ─────────
                  Text('Link a Reward (Optional)',
                      style: _poppins(size: 14, weight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (_selectedReward != null)
                    // Show selected reward card
                    Container(
                      decoration: BoxDecoration(
                        color: Color(_selectedReward!.colorValue)
                            .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Color(_selectedReward!.colorValue)
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Color(_selectedReward!.colorValue)
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(_selectedReward!.emoji,
                                  style: const TextStyle(fontSize: 22)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedReward!.title,
                                  style: _poppins(
                                    size: 14,
                                    weight: FontWeight.w600,
                                    color: Color(_selectedReward!.colorValue),
                                  ),
                                ),
                                Text(
                                  _selectedReward!.description,
                                  style: _poppins(
                                      size: 11, color: Colors.grey[500]!),
                                ),
                              ],
                            ),
                          ),
                          // Change button
                          IconButton(
                            icon: const Icon(Icons.swap_horiz, size: 20),
                            tooltip: 'Change reward',
                            color: Color(_selectedReward!.colorValue),
                            onPressed: _saving ? null : _openRewardPicker,
                          ),
                          // Remove button
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: 'Remove reward',
                            color: Colors.grey[400],
                            onPressed: _saving ? null : _clearReward,
                          ),
                        ],
                      ),
                    )
                  else
                    // "Add Reward" button
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _openRewardPicker,
                      icon: const Icon(Icons.card_giftcard, size: 18),
                      label: Text('Add Reward',
                          style: _poppins(size: 14, weight: FontWeight.w500)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6B21A8),
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  const SizedBox(height: 20),

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
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
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
}
