import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sound_service.dart';
import '../presentation/widgets/goal_alert_overlay.dart';
import 'goal_service.dart';

/// Singleton service that manages in-app goal notifications.
///
/// **Time Goal** — call [startTimeGoal] when the child enters the game area.
/// Alert thresholds:
///   target > 10 min  → alerts at 10, 5, 1 min left
///   target 6–10 min  → alerts at 5, 1 min left
///   target 2–5 min   → alert at 1 min left
///   target ≤ 1 min   → only "Time's Up!"
/// On time-up: shows a countdown banner, then navigates to the post-session
/// mood screen ("How do you feel now?").
///
/// **Star Goal** — call [checkStarGoal] whenever stars change.
/// Milestones: 50%, 80%, 100%.
/// At 100% a dismissible banner is shown — the child can continue playing.
class GoalNotificationService {
  GoalNotificationService._();
  static final GoalNotificationService instance = GoalNotificationService._();

  // ── Time goal state ──────────────────────────────────────────────
  Timer? _timer;
  int _elapsedMinutes = 0;
  int _targetMinutes = 0;
  String _goalId = '';
  final Set<int> _firedTimeAlerts = {};

  // ── Star goal state ──────────────────────────────────────────────
  // goalId → set of already-fired milestone keys ('50pct', '80pct', 'complete')
  final Map<String, Set<String>> _firedStarAlerts = {};

  // ── Time Goal ────────────────────────────────────────────────────

  /// [showSwitch] — true when the child is under an organisation account.
  /// When time is up, [showSwitch] decides whether to return to
  /// /orgz-child-dashboard (true) or /child-profiles (false).
  void startTimeGoal({
    required BuildContext context,
    required int targetMinutes,
    required String goalId,
    String? childName,
    bool showSwitch = false,
  }) {
    stopTimeGoal();

    _targetMinutes = targetMinutes;
    _elapsedMinutes = 0;
    _goalId = goalId;
    _firedTimeAlerts.clear();

    // The action tells /how-i-feel-end which screen to go to afterwards.
    final returnAction = showSwitch ? 'switch' : 'back-to-profiles';

    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _elapsedMinutes++;
      final remaining = _targetMinutes - _elapsedMinutes;

      if (remaining <= 0) {
        stopTimeGoal();
        if (!context.mounted) return;

        // Play time-up sound
        SoundService.instance.playTimeUp();

        // Show time-up banner with 5-second countdown, then redirect
        // to the post-session mood screen ("How do you feel now?").
        GoalAlertOverlay.show(
          context: context,
          message: "Time's Up! Amazing effort today! 🌟",
          alertType: GoalAlertType.timeUp,
          holdDuration: const Duration(seconds: 5),
          onDone: () async {
            // Time goal achieved — wipe the per-session goal set so the next
            // session starts fresh, and reset our star-alert tracking too.
            await GoalService.clearAll();
            resetAllStarAlerts();
            if (context.mounted) {
              context.go('/how-i-feel-end', extra: {
                'childName': childName,
                'action': returnAction,
              });
            }
          },
        );
        return;
      }

      final thresholds = _alertThresholds(_targetMinutes);
      if (thresholds.contains(remaining) &&
          !_firedTimeAlerts.contains(remaining)) {
        _firedTimeAlerts.add(remaining);
        if (!context.mounted) return;

        // Play warning sound scaled to urgency
        SoundService.instance.playTimeWarning(remaining);

        GoalAlertOverlay.show(
          context: context,
          message: remaining == 1
              ? 'Only 1 minute left! Wrap up soon! ⏱️'
              : '$remaining minutes left — keep going! 💪',
          alertType: GoalAlertType.timeWarning,
          holdDuration: const Duration(seconds: 4),
        );
      }
    });
  }

  Set<int> _alertThresholds(int totalMinutes) {
    if (totalMinutes > 10) return {10, 5, 1};
    if (totalMinutes >= 6) return {5, 1};
    if (totalMinutes >= 2) return {1};
    return {};
  }

  void stopTimeGoal() {
    _timer?.cancel();
    _timer = null;
  }

  bool get isTimerRunning => _timer != null;

  // ── Star Goal ────────────────────────────────────────────────────

  Future<void> checkStarGoal({
    required BuildContext context,
    required int currentStars,
    required int targetStars,
    required String goalId,
  }) async {
    if (targetStars <= 0) return;

    final fired = _firedStarAlerts.putIfAbsent(goalId, () => {});
    final fraction = currentStars / targetStars;

    // ── 100% complete ───────────────────────────────────────────────
    if (currentStars >= targetStars && !fired.contains('complete')) {
      fired.add('complete');
      fired.add('80pct');
      fired.add('50pct');

      SoundService.instance.playStarMilestone(1.0);

      if (context.mounted) {
        // Dismissible banner — child can keep playing
        GoalAlertOverlay.show(
          context: context,
          message:
              '🏆 Goal Complete! All $targetStars stars collected! You\'re a star!',
          alertType: GoalAlertType.starComplete,
          holdDuration: const Duration(seconds: 30),
        );
      }
      await GoalService.updateProgress(goalId, currentStars);
      return;
    }

    // ── 80% threshold ───────────────────────────────────────────────
    if (fraction >= 0.8 && !fired.contains('80pct')) {
      fired.add('80pct');
      final starsLeft = targetStars - currentStars;

      SoundService.instance.playStarMilestone(0.8);

      if (context.mounted) {
        GoalAlertOverlay.show(
          context: context,
          message:
              'Almost there! Only $starsLeft ${starsLeft == 1 ? "star" : "stars"} left! ⭐',
          alertType: GoalAlertType.starProgress,
          holdDuration: const Duration(seconds: 4),
        );
      }
    }

    // ── 50% threshold ───────────────────────────────────────────────
    if (fraction >= 0.5 && !fired.contains('50pct')) {
      fired.add('50pct');
      final starsLeft = targetStars - currentStars;

      SoundService.instance.playStarMilestone(0.5);

      if (context.mounted) {
        GoalAlertOverlay.show(
          context: context,
          message:
              'Halfway there! $starsLeft more ${starsLeft == 1 ? "star" : "stars"} to go! 🌟',
          alertType: GoalAlertType.starProgress,
          holdDuration: const Duration(seconds: 4),
        );
      }
    }

    await GoalService.updateProgress(goalId, currentStars);
  }

  void resetStarAlerts(String goalId) {
    _firedStarAlerts.remove(goalId);
  }

  /// Clears every per-goal star-alert tracking entry. Call this when the
  /// goal set itself is wiped (end of session / logout / profile switch)
  /// so the next session's milestones can fire fresh.
  void resetAllStarAlerts() {
    _firedStarAlerts.clear();
  }

  // ── Helpers ──────────────────────────────────────────────────────

  static Future<PerformanceGoal?> getActiveTimeGoal() async {
    final goals = await GoalService.getActiveGoals();
    try {
      return goals.firstWhere((g) => g.category == GoalCategory.timeSpent);
    } catch (_) {
      return null;
    }
  }

  static Future<List<PerformanceGoal>> getActiveStarGoals() async {
    final goals = await GoalService.getActiveGoals();
    return goals.where((g) => g.category == GoalCategory.starCollection).toList();
  }
}
