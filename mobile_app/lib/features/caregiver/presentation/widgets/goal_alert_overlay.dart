import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Alert type affects colour theming and behaviour.
enum GoalAlertType {
  timeWarning, // Orange — countdown reminder
  timeUp,      // Red — time is over, auto-redirects
  starProgress, // Amber — approaching star goal
  starComplete, // Green — star goal achieved, user must dismiss
}

/// Animated overlay banner that slides in from the top.
///
/// • [timeWarning] & [starProgress] — auto-dismiss after [holdDuration].
/// • [starComplete] — dismissible by user tap (shows a ✓ button).
/// • [timeUp] — shows a 5-second countdown then calls [onDone] so the
///   caller can navigate away.
class GoalAlertOverlay extends StatefulWidget {
  final String message;
  final GoalAlertType alertType;
  final VoidCallback onDone;
  final Duration holdDuration;

  const GoalAlertOverlay({
    super.key,
    required this.message,
    required this.alertType,
    required this.onDone,
    this.holdDuration = const Duration(seconds: 3),
  });

  /// Insert this overlay into the current [Overlay].
  ///
  /// [onDone] is called after the banner finishes (auto or manual dismiss).
  /// For [GoalAlertType.timeUp] pass a callback that navigates to profiles.
  static OverlayEntry show({
    required BuildContext context,
    required String message,
    required GoalAlertType alertType,
    Duration holdDuration = const Duration(seconds: 3),
    VoidCallback? onDone,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => GoalAlertOverlay(
        message: message,
        alertType: alertType,
        holdDuration: holdDuration,
        onDone: () {
          entry.remove();
          onDone?.call();
        },
      ),
    );
    overlay.insert(entry);
    return entry;
  }

  @override
  State<GoalAlertOverlay> createState() => _GoalAlertOverlayState();
}

class _GoalAlertOverlayState extends State<GoalAlertOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slideY;
  late Animation<double> _scale;
  late Animation<double> _fade;

  // For timeUp countdown
  int _countdown = 5;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideY = Tween<double>(begin: -140, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _scale = Tween<double>(begin: 0.80, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.35)),
    );
    _ctrl.forward();

    if (widget.alertType == GoalAlertType.timeUp) {
      _startCountdown();
    } else if (widget.alertType != GoalAlertType.starComplete) {
      // Auto-dismiss for warnings and star progress
      Future.delayed(widget.holdDuration, _dismiss);
    }
    // starComplete: waits for user tap
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        _dismiss();
      }
    });
  }

  Future<void> _dismiss() async {
    _countdownTimer?.cancel();
    if (mounted) {
      await _ctrl.reverse();
      widget.onDone();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Color get _bgColor {
    switch (widget.alertType) {
      case GoalAlertType.timeWarning:
        return const Color(0xFFF97316);
      case GoalAlertType.timeUp:
        return const Color(0xFFEF4444);
      case GoalAlertType.starProgress:
        return const Color(0xFFF59E0B);
      case GoalAlertType.starComplete:
        return const Color(0xFF22C55E);
    }
  }

  String get _leadingEmoji {
    switch (widget.alertType) {
      case GoalAlertType.timeWarning:
        return '⏰';
      case GoalAlertType.timeUp:
        return '🛑';
      case GoalAlertType.starProgress:
        return '⭐';
      case GoalAlertType.starComplete:
        return '🎉';
    }
  }

  bool get _isDismissible =>
      widget.alertType == GoalAlertType.starComplete;

  bool get _isTimeUp => widget.alertType == GoalAlertType.timeUp;

  @override
  Widget build(BuildContext context) {
    final textColor =
        _bgColor.computeLuminance() > 0.4 ? Colors.black87 : Colors.white;
    final shimmer = textColor.withValues(alpha: 0.22);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Opacity(
          opacity: _fade.value,
          child: Transform.translate(
            offset: Offset(0, _slideY.value),
            child: Transform.scale(scale: _scale.value, child: child),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _bgColor,
                      Color.lerp(_bgColor, Colors.white, 0.22)!,
                      _bgColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: shimmer, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _bgColor.withValues(alpha: 0.55),
                      blurRadius: 28,
                      spreadRadius: 2,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.28),
                      blurRadius: 6,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_leadingEmoji,
                            style: const TextStyle(fontSize: 26)),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            widget.message,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.baloo2(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(_leadingEmoji,
                            style: const TextStyle(fontSize: 26)),
                      ],
                    ),

                    // ── Time-up countdown ──────────────────────────
                    if (_isTimeUp) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Going back in $_countdown...',
                        style: GoogleFonts.baloo2(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ],

                    // ── Star-complete dismiss button ───────────────
                    if (_isDismissible) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _dismiss,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            'Awesome! Keep Playing! 🚀',
                            style: GoogleFonts.baloo2(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
