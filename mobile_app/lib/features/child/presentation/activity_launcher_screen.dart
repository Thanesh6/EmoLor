import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity_item.dart';
import '../models/activity_session.dart';
import '../models/activity_save_state.dart';
import '../services/instructions_service.dart';
import '../../../core/logic/adaptive_engine.dart';
import '../../../screens/play_screen.dart';
import '../../../screens/draw_screen.dart';
import '../../../screens/stories_screen.dart';
import 'instructions_overlay.dart';

/// UCD013 + UCD014 – Activity Launcher.
///
/// **Fresh start (UCD013):**
///   1. Show a child-friendly loading screen ("Getting ready…")
///   2. Consult the Adaptive Sensory Engine → compute difficulty parameters
///   3. Check if instructions have been seen before (SharedPreferences)
///      – If not, show an instructions dialog and persist the flag
///   4. Simulate asset loading
///   5. Navigate-replace to the real activity screen
///   6. Start internal timer (via [ActivitySession.startedAt])
///
/// **Resume flow (UCD014):**
///   When [savedState] is non-null the launcher:
///   • Skips instructions (the child has already seen them).
///   • Restores difficulty, speed, and elapsed time from the save.
///   • Resumes the session timer at [savedState.elapsedSeconds].
///   Alt-flow: if the save data was corrupted the caller passes `null`
///   and the normal fresh-start path runs automatically.
class ActivityLauncherScreen extends StatefulWidget {
  final ActivityItem activity;

  /// If non-null the launcher enters **resume mode** (UCD014).
  final ActivitySaveState? savedState;

  const ActivityLauncherScreen({
    super.key,
    required this.activity,
    this.savedState,
  });

  @override
  State<ActivityLauncherScreen> createState() => _ActivityLauncherScreenState();
}

class _ActivityLauncherScreenState extends State<ActivityLauncherScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    // Kick off the launch sequence after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _launchSequence());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── Launch sequence ───────────────────────────────────────────────────
  Future<void> _launchSequence() async {
    try {
      final bool isResuming = widget.savedState != null;

      // Step 2: Compute difficulty (from save or Adaptive Engine)
      if (isResuming) {
        _restoreSession(widget.savedState!);
      } else {
        _computeDifficulty();
      }

      // Step 4-5: Show instructions only on a fresh start
      if (!isResuming) {
        await _maybeShowInstructions();
      }

      // Step 6: Simulate asset loading (in production this would be real I/O)
      await Future<void>.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;

      // Step 7: Navigate to the real activity screen
      final Widget target = _resolveScreen();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => target),
      );
    } catch (e) {
      // Alt-Flow: Resource Load Error
      if (!mounted) return;
      setState(() => _hasError = true);
      await _showErrorDialog();
    }
  }

  // ── UCD014: Restore session from saved state ──────────────────────────
  ActivitySession _restoreSession(ActivitySaveState saved) {
    // Resume the timer by offsetting startedAt so that
    // elapsedSeconds picks up where the child left off.
    final resumedStart =
        DateTime.now().subtract(Duration(seconds: saved.elapsedSeconds));

    return ActivitySession(
      activityId: saved.activityId,
      difficultyLevel: saved.difficultyLevel,
      speedMultiplier: saved.speedMultiplier,
      itemCount: 5, // kept at default; could be saved later
      instructionsAlreadySeen: true, // always skip on resume
      startedAt: resumedStart,
    );
  }

  // ── Step 2-3: Adaptive Engine → difficulty ────────────────────────────
  ActivitySession _computeDifficulty() {
    // Create a fresh AdaptiveEngine instance to read current state.
    // In production, this would pull the child's historical session data
    // from the DB to seed the engine.
    final engine = AdaptiveEngine();

    int difficultyLevel = 1; // default easy
    double speed = 1.0;
    int items = 5;

    // If the engine detects prior frustration or overload, ease off
    if (engine.shouldSimplify) {
      difficultyLevel = 1;
      speed = 0.7;
      items = 3;
    } else {
      // Placeholder: higher difficulty for returning players
      difficultyLevel = 1;
      speed = 1.0;
      items = 5;
    }

    return ActivitySession(
      activityId: widget.activity.id,
      difficultyLevel: difficultyLevel,
      speedMultiplier: speed,
      itemCount: items,
      startedAt: DateTime.now(),
    );
  }

  // ── Step 4-5: Instructions (UCD015 – shown only once per activity) ──
  Future<void> _maybeShowInstructions() async {
    final instrService = InstructionsService.instance;

    // Alt-flow: no instructions defined → skip this step entirely.
    if (!instrService.hasInstructions(widget.activity.id)) return;

    final prefs = await SharedPreferences.getInstance();
    final key = 'instructions_seen_${widget.activity.id}';
    final alreadySeen = prefs.getBool(key) ?? false;

    if (alreadySeen || !mounted) return;

    // Show the new InstructionsOverlay (visual + TTS)
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => InstructionsOverlay(
        emoji: widget.activity.emoji,
        activityName: widget.activity.name,
        instructionText: instrService.getInstructions(widget.activity.id)!,
        dismissLabel: "Let's Go! 🚀",
      ),
    );

    // Persist that instructions have been seen
    await prefs.setBool(key, true);
  }

  // ── Step 6: Resolve the target screen ─────────────────────────────────
  Widget _resolveScreen() {
    switch (widget.activity.category) {
      case ActivityCategory.games:
        return const PlayScreen();
      case ActivityCategory.drawing:
        return const DrawScreen();
      case ActivityCategory.stories:
        return const StoriesScreen();
    }
  }

  // ── Alt-Flow: Error dialog ────────────────────────────────────────────
  Future<void> _showErrorDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            const Text('😢', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 10),
            Text('Oops!',
                style: GoogleFonts.baloo2(
                    fontSize: 26, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          'Something went wrong loading this activity.\nLet\'s go back and try again!',
          style: GoogleFonts.baloo2(fontSize: 16, color: Colors.black54),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            ),
            onPressed: () {
              Navigator.pop(ctx); // close dialog
              Navigator.pop(context); // return to Browse
            },
            child: Text('Go Back',
                style: GoogleFonts.baloo2(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Build: child-friendly loading screen ──────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pulsing emoji
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, child) {
                    final scale = 1.0 + 0.15 * _pulseController.value;
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Text(
                    widget.activity.emoji,
                    style: const TextStyle(fontSize: 80),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _hasError ? 'Oops! 😢' : 'Getting ready…',
                  style: GoogleFonts.baloo2(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: const [
                      Shadow(
                          offset: Offset(2, 2),
                          blurRadius: 6,
                          color: Colors.black26),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.activity.name,
                  style: GoogleFonts.baloo2(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 30),
                if (!_hasError)
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 4,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Instructions are now handled by InstructionsOverlay + InstructionsService
// (UCD015). The old _InstructionsDialog class has been removed.
// ═══════════════════════════════════════════════════════════════════════
