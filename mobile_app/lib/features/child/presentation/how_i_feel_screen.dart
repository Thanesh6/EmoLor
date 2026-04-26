import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/emotion_service.dart';
import '../../../core/services/emotion_colour_mapping.dart';
import '../../caregiver/services/goal_notification_service.dart';
import '../../caregiver/services/goal_service.dart';
import '../domain/models/emotion.dart';
import '../services/child_session_service.dart';

enum HowIFeelMode { start, end }

enum _Phase { pickEmotion, colorForSelected }

class HowIFeelEmotionChoice {
  final String id, name, emoji, valence;
  final Color color;
  const HowIFeelEmotionChoice(this.id, this.name, this.emoji, this.color, this.valence);
}

/// Session-time emotion screen.
///
/// **Pre-session (start):**
///   1. All 8 emotions shown colourless. Persistent palette is ignored.
///   2. Child picks an emotion → inline colour picker (always).
///   3. Picked colour is saved to the current session only.
///   4. Proceed to games.
///
/// **Post-session (end):**
///   1. All 8 emotions shown colourless EXCEPT the one chosen pre-session,
///      which appears in the colour the child picked at the start.
///   2. Tapping the same emotion → continue. Tapping a different (grey)
///      one → inline colour picker, then continue.
class HowIFeelScreen extends StatefulWidget {
  final HowIFeelMode mode;
  final String? childName;
  final Future<void> Function(HowIFeelEmotionChoice choice) onContinue;
  final VoidCallback? onBack;

  const HowIFeelScreen({
    super.key,
    required this.mode,
    required this.onContinue,
    this.childName,
    this.onBack,
  });

  @override
  State<HowIFeelScreen> createState() => _HowIFeelScreenState();
}

class _HowIFeelScreenState extends State<HowIFeelScreen>
    with TickerProviderStateMixin {

  // ── Phase state ──────────────────────────────────────────────────────────
  _Phase _phase = _Phase.pickEmotion;
  Emotion? _selectedEmotion;   // emotion child tapped in phase 1
  Color? _pickedColor;         // colour chosen in current picker phase

  // ── Data ─────────────────────────────────────────────────────────────────
  List<Emotion> _emotions = EmotionService.defaultEmotions;
  Set<String> _assignedIds = {};

  // ── Animation ────────────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  bool _busy = false;

  // ── 12-colour palette (same as My Colours) ───────────────────────────────
  static const List<Color> _palette = [
    Color(0xFFEF4444), // Red
    Color(0xFFF97316), // Orange
    Color(0xFFFFE66D), // Yellow
    Color(0xFF22C55E), // Green
    Color(0xFF4ECDC4), // Teal
    Color(0xFF60A5FA), // Sky Blue
    Color(0xFF74B9FF), // Light Blue
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFFFF7EB3), // Rose
    Color(0xFFFF9F43), // Amber
    Color(0xFF9CA3AF), // Gray
  ];

  static const Color _unassignedBg = Color(0xFFD1D5DB); // grey for unassigned

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
    _init();
  }

  Future<void> _init() async {
    await EmotionColourMapping.ensureLoaded();
    // Start with the canonical 8 emotions but treat them all as colourless
    // — the persistent personalized palette is intentionally ignored here.
    final emotions = EmotionService.defaultEmotions;

    if (widget.mode == HowIFeelMode.start) {
      if (mounted) {
        setState(() {
          _emotions = emotions;
          _assignedIds = {};
        });
      }
      return;
    }

    // End mode: paint the one emotion picked in this session's pre-screen.
    final pre = await ChildSessionService.getSessionPreEmotion();
    final preId = pre.emotionId;
    final preHex = pre.colourHex;
    final preColor = (preHex != null) ? _hexToColor(preHex) : null;

    if (mounted) {
      setState(() {
        if (preId != null && preColor != null) {
          _emotions = emotions
              .map((e) => e.id == preId ? e.copyWith(color: preColor) : e)
              .toList();
          _assignedIds = {preId};
        } else {
          _emotions = emotions;
          _assignedIds = {};
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Phase transitions ────────────────────────────────────────────────────

  void _onEmotionTapped(Emotion e) {
    setState(() {
      _selectedEmotion = e;
      _pickedColor = null;
    });

    final isAssigned = _assignedIds.contains(e.id);
    if (!isAssigned) {
      setState(() => _phase = _Phase.colorForSelected);
    } else {
      _afterSelectedHandled();
    }
  }

  void _afterSelectedHandled() {
    // No more "bonus round" — go straight to finish in both modes.
    _finish();
  }

  Future<void> _confirmSelectedColor() async {
    if (_pickedColor == null || _selectedEmotion == null) return;
    final color = _pickedColor!;
    final id = _selectedEmotion!.id;

    _assignedIds.add(id);

    setState(() {
      _emotions = _emotions
          .map((e) => e.id == id ? e.copyWith(color: color) : e)
          .toList();
      _selectedEmotion = _selectedEmotion!.copyWith(color: color);
    });

    // Pre-session: stash the picked colour for this session only so the
    // post-session screen can show the matching card already coloured.
    if (widget.mode == HowIFeelMode.start) {
      await ChildSessionService.setSessionPreEmotion(
        emotionId: id,
        colourHex: _colorToHex(color),
      );
    }

    _afterSelectedHandled();
  }

  Future<void> _finish() async {
    if (_selectedEmotion == null) return;
    setState(() => _busy = true);

    final choice = HowIFeelEmotionChoice(
      _selectedEmotion!.id,
      _selectedEmotion!.name,
      _selectedEmotion!.emoji,
      _selectedEmotion!.color,
      _selectedEmotion!.valence,
    );

    await _saveMoodLocally(choice);
    await _saveMoodToDatabase(choice);

    // End-of-session housekeeping: drop the per-session pre-emotion record,
    // and clear all per-session goals so the next session starts fresh.
    if (widget.mode == HowIFeelMode.end) {
      await ChildSessionService.clearSessionPreEmotion();
      await GoalService.clearAll();
      GoalNotificationService.instance.resetAllStarAlerts();
    }

    try {
      await widget.onContinue(choice);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveMoodLocally(HowIFeelEmotionChoice choice) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final suffix = widget.mode == HowIFeelMode.start ? 'start' : 'end';
      await prefs.setString('how_i_feel_${suffix}_id', choice.id);
      await prefs.setString('how_i_feel_${suffix}_name', choice.name);
      await prefs.setString('how_i_feel_${suffix}_at', DateTime.now().toIso8601String());
    } catch (_) {}
  }

  Future<void> _saveMoodToDatabase(HowIFeelEmotionChoice choice) async {
    final hex = EmotionColourMapping.hexFor(choice.name);
    try {
      if (widget.mode == HowIFeelMode.start) {
        await ChildSessionService.recordPreEmotion(
          emotionName: choice.name,
          emotionValence: choice.valence,
          emotionColourHex: hex,
        );
      } else {
        await ChildSessionService.recordPostEmotion(
          emotionName: choice.name,
          emotionValence: choice.valence,
          emotionColourHex: hex,
        );
      }
    } catch (e) {
      debugPrint('HowIFeelScreen._saveMoodToDatabase: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  TextStyle _cute({
    double size = 22,
    FontWeight weight = FontWeight.w700,
    Color color = Colors.white,
    List<Shadow>? shadows,
  }) =>
      GoogleFonts.baloo2(fontSize: size, fontWeight: weight, color: color, shadows: shadows);

  Color _cardBg(Emotion e) =>
      _assignedIds.contains(e.id) ? e.color : _unassignedBg;

  /// Parse `#RRGGBB` (or `#AARRGGBB`) to a [Color].
  static Color _hexToColor(String hex) {
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 6) h = 'FF$h'; // add full alpha
    final value = int.tryParse(h, radix: 16);
    if (value == null) return _unassignedBg;
    return Color(value);
  }

  static String _colorToHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE8F0), Color(0xFFE0C3FC), Color(0xFF8EC5FC)],
          ),
        ),
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 340),
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
              return SlideTransition(position: slide, child: FadeTransition(opacity: animation, child: child));
            },
            child: switch (_phase) {
              _Phase.pickEmotion    => _buildPickPhase(),
              _Phase.colorForSelected => _buildColorPickerPhase(
                key: const ValueKey('color-selected'),
                emotion: _selectedEmotion!,
                onConfirm: _confirmSelectedColor,
              ),
            },
          ),
        ),
      ),
    );
  }

  // ── Phase 1: emotion grid ─────────────────────────────────────────────────

  Widget _buildPickPhase() {
    final greeting = (widget.childName?.isNotEmpty == true)
        ? 'Hi ${widget.childName}!'
        : 'Hello friend!';
    final title = widget.mode == HowIFeelMode.start
        ? 'How do you feel today?'
        : 'How are you feeling now?';
    final subtitle = widget.mode == HowIFeelMode.start
        ? 'Tap the emoji that matches you right now'
        : 'Thanks for playing! Tap how you feel now';

    return Stack(
      key: const ValueKey('pick'),
      children: [
        Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Column(
                children: [
                  Text(greeting,
                      style: _cute(size: 26, color: const Color(0xFF6B21A8))),
                  const SizedBox(height: 4),
                  Text(title,
                      style: _cute(
                        size: 38,
                        weight: FontWeight.w900,
                        color: const Color(0xFF1B2541),
                        shadows: const [Shadow(offset: Offset(2, 2), blurRadius: 4, color: Colors.black26)],
                      ),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: _cute(size: 17, weight: FontWeight.w500, color: Colors.black54),
                      textAlign: TextAlign.center),
                ],
              ),
            ),

            // Emotion grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.88,
                  ),
                  itemCount: _emotions.length,
                  itemBuilder: (context, i) {
                    final e = _emotions[i];
                    final bg = _cardBg(e);
                    final isAssigned = _assignedIds.contains(e.id);
                    final isSelected = _selectedEmotion?.id == e.id;
                    return AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, child) => Transform.scale(
                        scale: isSelected ? 1.0 + _pulseCtrl.value * 0.04 : 1.0,
                        child: child,
                      ),
                      child: GestureDetector(
                        onTap: () => _onEmotionTapped(e),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [bg, bg.withValues(alpha: 0.75)],
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isSelected ? Colors.yellow : Colors.white,
                              width: isSelected ? 4.5 : 3.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: bg.withValues(alpha: isSelected ? 0.65 : 0.3),
                                blurRadius: isSelected ? 20 : 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(e.emoji, style: const TextStyle(fontSize: 68)),
                                    const SizedBox(height: 4),
                                    Text(
                                      e.name,
                                      style: _cute(
                                        size: 24,
                                        weight: FontWeight.w800,
                                        color: isAssigned ? Colors.white : Colors.black54,
                                        shadows: isAssigned
                                            ? const [Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black26)]
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Paint icon hint for unassigned emotions —
                              // tapping these leads to the colour picker.
                              if (!isAssigned)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.palette_rounded, size: 16, color: Color(0xFF6B21A8)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Continue button (appears after selection)
            AnimatedOpacity(
              opacity: _selectedEmotion != null ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
                child: SizedBox(
                  width: 320,
                  height: 64,
                  child: ElevatedButton.icon(
                    onPressed: _selectedEmotion == null || _busy ? null : () {
                      final e = _selectedEmotion!;
                      final isAssigned = _assignedIds.contains(e.id);
                      if (!isAssigned) {
                        setState(() => _phase = _Phase.colorForSelected);
                      } else {
                        _afterSelectedHandled();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedEmotion != null ? _cardBg(_selectedEmotion!) : Colors.grey.shade300,
                      foregroundColor: Colors.white,
                      elevation: 6,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    ),
                    icon: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                        : const Icon(Icons.arrow_forward_rounded, size: 28),
                    label: Text(
                      widget.mode == HowIFeelMode.start ? 'Continue' : 'Done',
                      style: _cute(size: 24, weight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        // Back button
        if (widget.mode == HowIFeelMode.start && widget.onBack != null)
          Positioned(
            top: 10,
            left: 14,
            child: GestureDetector(
              onTap: widget.onBack,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF6B21A8), size: 30),
              ),
            ),
          ),
      ],
    );
  }

  // ── Phase 2: inline colour picker ────────────────────────────────────────

  Widget _buildColorPickerPhase({
    required Key key,
    required Emotion emotion,
    required Future<void> Function() onConfirm,
  }) {
    const title = 'Pick a colour for this feeling';
    final subtitle = 'What colour is ${emotion.emoji} ${emotion.name}?';

    return Column(
      key: key,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Column(
            children: [
              Text(title,
                  style: _cute(size: 38, weight: FontWeight.w900, color: const Color(0xFF1B2541)),
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(subtitle,
                  style: _cute(size: 26, weight: FontWeight.w600, color: Colors.black54),
                  textAlign: TextAlign.center),
            ],
          ),
        ),

        // Big colour preview circle with emoji
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            color: _pickedColor ?? _unassignedBg,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 6),
            boxShadow: [
              BoxShadow(
                color: (_pickedColor ?? _unassignedBg).withValues(alpha: 0.5),
                blurRadius: 36,
                spreadRadius: 6,
              ),
            ],
          ),
          child: Center(
            child: Text(emotion.emoji, style: const TextStyle(fontSize: 86)),
          ),
        ),
        const SizedBox(height: 20),

        // 12-colour palette — constrained width keeps circles compact
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: _palette.length,
              itemBuilder: (context, i) {
                final c = _palette[i];
                final isChosen = _pickedColor?.toARGB32() == c.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _pickedColor = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isChosen ? Colors.white : Colors.transparent,
                        width: isChosen ? 4 : 0,
                      ),
                      boxShadow: isChosen
                          ? [BoxShadow(color: c.withValues(alpha: 0.7), blurRadius: 16, spreadRadius: 2)]
                          : [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4)],
                    ),
                    child: isChosen
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                        : null,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Confirm button
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: SizedBox(
            width: 380,
            height: 72,
            child: ElevatedButton.icon(
              onPressed: _pickedColor == null || _busy ? null : onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: _pickedColor ?? Colors.grey.shade300,
                disabledBackgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.white,
                elevation: _pickedColor != null ? 6 : 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              ),
              icon: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 28),
              label: Text(
                "That's my colour! ✓",
                style: _cute(size: 26, weight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
