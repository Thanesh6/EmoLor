import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/goal_service.dart';

/// UCD025 — Reward picker modal.
///
/// Displays a scrollable list of available in-app rewards (badges,
/// themes, extras) with visual icons. The caregiver selects one to
/// link to the current goal draft, or taps Cancel / Back to close
/// without linking.
class RewardPickerModal extends StatefulWidget {
  /// The currently selected reward id (if any), to show a check mark.
  final String? currentRewardId;

  const RewardPickerModal({super.key, this.currentRewardId});

  /// Show the modal and return the selected [RewardOption], or `null`
  /// if the caregiver cancels.
  static Future<RewardOption?> show(
    BuildContext context, {
    String? currentRewardId,
  }) {
    return showModalBottomSheet<RewardOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RewardPickerModal(currentRewardId: currentRewardId),
    );
  }

  @override
  State<RewardPickerModal> createState() => _RewardPickerModalState();
}

class _RewardPickerModalState extends State<RewardPickerModal> {
  String? _hoveredId;

  TextStyle _poppins({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = Colors.black87,
  }) {
    return GoogleFonts.poppins(
        fontSize: size, fontWeight: weight, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ───────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Header ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Icon(Icons.card_giftcard,
                    color: Color(0xFF6B21A8), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Choose a Reward',
                    style: _poppins(
                      size: 20,
                      weight: FontWeight.w700,
                      color: const Color(0xFF6B21A8),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel',
                      style: _poppins(
                          size: 14,
                          weight: FontWeight.w500,
                          color: Colors.grey[600]!)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Select a reward to link to this goal. Your child will earn it upon completion.',
              style: _poppins(size: 13, color: Colors.grey[500]!),
            ),
          ),
          const SizedBox(height: 16),

          // ── Reward list ───────────────────────────────────────
          Flexible(
            child: ListView.separated(
              padding:
                  EdgeInsets.only(left: 16, right: 16, bottom: 24 + bottomPad),
              shrinkWrap: true,
              itemCount: availableRewardOptions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final reward = availableRewardOptions[index];
                final isSelected = reward.id == widget.currentRewardId;
                final rewardColor = Color(reward.colorValue);

                return MouseRegion(
                  onEnter: (_) => setState(() => _hoveredId = reward.id),
                  onExit: (_) => setState(() => _hoveredId = null),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? rewardColor.withValues(alpha: 0.12)
                          : _hoveredId == reward.id
                              ? Colors.grey[50]
                              : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? rewardColor : Colors.grey[200]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(reward),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            // Reward icon
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: rewardColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(reward.emoji,
                                    style: const TextStyle(fontSize: 26)),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Title + description
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reward.title,
                                    style: _poppins(
                                      size: 15,
                                      weight: FontWeight.w600,
                                      color: isSelected
                                          ? rewardColor
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    reward.description,
                                    style: _poppins(
                                        size: 12, color: Colors.grey[500]!),
                                  ),
                                ],
                              ),
                            ),

                            // Selection indicator
                            if (isSelected)
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: rewardColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check,
                                    color: Colors.white, size: 18),
                              )
                            else
                              Icon(Icons.chevron_right,
                                  color: Colors.grey[300], size: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
