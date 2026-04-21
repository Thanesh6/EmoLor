import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Alert type affects colour theming and behaviour.
enum GoalAlertType {
  timeWarning,  // Orange — countdown reminder
  timeUp,       // Red — time is over, auto-redirects (blocking)
  starProgress, // Amber — approaching star goal
  starComplete, // Green — star goal achieved, user must dismiss (blocking)
}

/// Animated centred-rectangle overlay that pops in from the middle of the screen.
///
/// • [timeWarning] & [starProgress] — auto-dismiss after [holdDuration].
/// • [starComplete]  — user must tap "Keep Playing" to dismiss.
/// • [timeUp]        — shows a 5-second countdown then calls [onDone].
///
/// Blocking types (timeUp, starComplete) dim the screen behind the card.
/// Non-blocking types (timeWarning, starProgress) float above the UI with
/// no dim so the child can still see the game underneath.
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

  /// Insert this overlay into the **root** Overlay (above all routes/games).
  ///
  /// [onDone] is called after the banner finishes (auto or manual dismiss).
  static OverlayEntry show({
    required BuildContext context,
    required String message,
    required GoalAlertType alertType,
    Duration holdDuration = const Duration(seconds: 3),
    VoidCallback? onDone,
  }) {
    // rootOverlay: true  ←  ensures the entry sits above any pushed route
    // (including game screens opened via Navigator.push).
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => GoalAlertOverlay(
        message: message,
        alertType: alertType,
        holdDuration: holdDuration,
        onDone: () {
          if (entry.mounted) entry.remove();
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
      duration: const Duration(milliseconds: 380),
    );

    // Pop-in from centre: scale 0.72 → 1.0, fade 0 → 1
    _scale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.5)),
    );

    _ctrl.forward();

    if (widget.alertType == GoalAlertType.timeUp) {
      _startCountdown();
    } else if (widget.alertType != GoalAlertType.starComplete) {
      // Auto-dismiss warnings / progress banners
      Future.delayed(widget.holdDuration, _dismiss);
    }
    // starComplete: waits for user tap
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        _dismiss();
      }
    });
  }

  Future<void> _dismiss() async {
    _countdownTimer?.cancel();
    if (!mounted) return;
    await _ctrl.reverse();
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  // ── Theming ──────────────────────────────────────────────────────────

  Color get _bgColor {
    switch (widget.alertType) {
      case GoalAlertType.timeWarning:  return const Color(0xFFF97316);
      case GoalAlertType.timeUp:       return const Color(0xFFEF4444);
      case GoalAlertType.starProgress: return const Color(0xFFF59E0B);
      case GoalAlertType.starComplete: return const Color(0xFF22C55E);
    }
  }

  String get _leadingEmoji {
    switch (widget.alertType) {
      case GoalAlertType.timeWarning:  return '⏰';
      case GoalAlertType.timeUp:       return '🛑';
      case GoalAlertType.starProgress: return '⭐';
      case GoalAlertType.starComplete: return '🎉';
    }
  }

  bool get _isDismissible => widget.alertType == GoalAlertType.starComplete;
  bool get _isBlocking =>
      widget.alertType == GoalAlertType.timeUp ||
      widget.alertType == GoalAlertType.starComplete;
  bool get _isTimeUp => widget.alertType == GoalAlertType.timeUp;

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final textColor =
        _bgColor.computeLuminance() > 0.4 ? Colors.black87 : Colors.white;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        return Stack(
          children: [
            // ── Dim backdrop for blocking alert types ───────────────
            if (_isBlocking)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: false, // absorbs taps when blocking
                  child: Opacity(
                    opacity: _fade.value * 0.55,
                    child: ColoredBox(color: Colors.black),
                  ),
                ),
              ),

            // ── Centred rectangle card ──────────────────────────────
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Opacity(
                  opacity: _fade.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          // Constrained width — looks like a proper centred dialog card
          margin: const EdgeInsets.symmetric(horizontal: 40),
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _bgColor,
                Color.lerp(_bgColor, Colors.white, 0.18)!,
                _bgColor,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.30),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _bgColor.withValues(alpha: 0.60),
                blurRadius: 40,
                spreadRadius: 4,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Big emoji ────────────────────────────────────────
              Text(
                _leadingEmoji,
                style: const TextStyle(fontSize: 52),
              ),
              const SizedBox(height: 14),

              // ── Message ──────────────────────────────────────────
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  height: 1.25,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),

              // ── Time-up countdown ─────────────────────────────────
              if (_isTimeUp) ...[
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    'Going back in $_countdown...',
                    style: GoogleFonts.baloo2(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: textColor.withValues(alpha: 0.90),
                    ),
                  ),
                ),
              ],

              // ── Star-complete dismiss button ───────────────────────
              if (_isDismissible) ...[
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _dismiss,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.32),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.55),
                          width: 2),
                    ),
                    child: Text(
                      'Awesome! Keep Playing! 🚀',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        fontSize: 18,
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
    );
  }
}
