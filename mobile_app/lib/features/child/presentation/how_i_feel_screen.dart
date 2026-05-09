import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/emotion_service.dart';
import '../../../core/services/emotion_colour_mapping.dart';
import '../../caregiver/services/goal_notification_service.dart';
import '../../caregiver/services/goal_service.dart';
import '../domain/models/emotion.dart';
import '../services/child_session_service.dart';
import '../../../core/services/bg_music_player.dart';
import '../../../core/constants/sensory_palette.dart';

enum HowIFeelMode { start, end }

enum _Phase { pickEmotion, colorForSelected }

class HowIFeelEmotionChoice {
  final String id, name, emoji, valence;
  final Color color;
  const HowIFeelEmotionChoice(
      this.id, this.name, this.emoji, this.color, this.valence);
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
  Emotion? _selectedEmotion; // emotion child tapped in phase 1
  Color? _pickedColor; // colour chosen in current picker phase

  // ── Data ─────────────────────────────────────────────────────────────────
  List<Emotion> _emotions = EmotionService.defaultEmotions;
  Set<String> _assignedIds = {};

  // ── Animation ────────────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  bool _busy = false;

  // ── Standardized 9-colour sensory palette ────────────────────────────────
  static List<Color> get _palette =>
      SensoryPalette.colors.map((c) => c.color).toList();

  // Background flush color when child taps a color bubble
  Color? _flushColor;

  // Shuffled palette — randomized each time color picker is shown
  List<Color> _shuffledPalette = [];

  static const Color _unassignedBg = Color(0xFFD1D5DB); // grey for unassigned

  @override
  void initState() {
    super.initState();

    if (widget.mode == HowIFeelMode.start) {
      BgMusicPlayer.instance.play();
    }

    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
    _shuffledPalette = [..._palette]..shuffle();
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
    final shuffled = [..._palette]..shuffle();
    setState(() {
      _selectedEmotion = e;
      _pickedColor = null;
      _shuffledPalette = shuffled;
    });

    final isAssigned = _assignedIds.contains(e.id);

    // Pre-session:
    // - If emotion is not assigned, ask child to pick a colour.
    // - If already assigned, continue.
    //
    // Post-session:
    // - Always ask child to pick a colour, even if the same emotion was selected.
    if (widget.mode == HowIFeelMode.end) {
      setState(() {
        _shuffledPalette = [..._palette]..shuffle();
        _phase = _Phase.colorForSelected;
      });
    } else if (!isAssigned) {
      setState(() {
        _shuffledPalette = [..._palette]..shuffle();
        _phase = _Phase.colorForSelected;
      });
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
        colourHex: _canonicalHex(color),
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

      if (widget.mode == HowIFeelMode.end) {
        await BgMusicPlayer.instance.stop();
      }
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
      await prefs.setString(
          'how_i_feel_${suffix}_at', DateTime.now().toIso8601String());
    } catch (_) {}
  }

  Future<void> _saveMoodToDatabase(HowIFeelEmotionChoice choice) async {
    final hex = _colorToHex(choice.color);

    debugPrint(
      'HowIFeelScreen._saveMoodToDatabase called | '
      'mode=${widget.mode} | '
      'emotion=${choice.name} | '
      'valence=${choice.valence} | '
      'hex=$hex',
    );

    try {
      if (widget.mode == HowIFeelMode.start) {
        debugPrint('Calling ChildSessionService.recordPreEmotion...');
        await ChildSessionService.recordPreEmotion(
          emotionName: choice.name,
          emotionValence: choice.valence,
          emotionColourHex: hex,
        );
        debugPrint('Finished ChildSessionService.recordPreEmotion');
      } else {
        debugPrint('Calling ChildSessionService.recordPostEmotion...');
        await ChildSessionService.recordPostEmotion(
          emotionName: choice.name,
          emotionValence: choice.valence,
          emotionColourHex: hex,
        );
        debugPrint('Finished ChildSessionService.recordPostEmotion');
      }
    } catch (e) {
      debugPrint('HowIFeelScreen._saveMoodToDatabase ERROR: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  TextStyle _cute({
    double size = 22,
    FontWeight weight = FontWeight.w700,
    Color color = Colors.white,
    List<Shadow>? shadows,
  }) =>
      GoogleFonts.baloo2(
          fontSize: size, fontWeight: weight, color: color, shadows: shadows);

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

  /// Returns the canonical hex from SensoryPalette for a given Color,
  /// falling back to computed hex if not found.
  static String _canonicalHex(Color c) {
    final computed = _colorToHex(c);
    final found = SensoryPalette.colors
        .where((s) => s.color.toARGB32() == c.toARGB32())
        .firstOrNull;
    return found?.hex ?? computed;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF7DD3FC),
              Color(0xFFFDE68A),
              Color(0xFF86EFAC),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            gradient: _flushColor != null
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _flushColor!.withValues(alpha: 0.6),
                      _flushColor!.withValues(alpha: 0.3),
                      const Color(0xFF86EFAC),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  )
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF7DD3FC),
                      Color(0xFFFDE68A),
                      Color(0xFF86EFAC),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
          ),
          child: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 340),
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                    parent: animation, curve: Curves.easeOutCubic));
                return SlideTransition(
                    position: slide,
                    child: FadeTransition(opacity: animation, child: child));
              },
              child: switch (_phase) {
                _Phase.pickEmotion => _buildPickPhase(),
                _Phase.colorForSelected => _buildColorPickerPhase(
                    key: const ValueKey('color-selected'),
                    emotion: _selectedEmotion!,
                    onConfirm: _confirmSelectedColor,
                  ),
              },
            ),
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
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Column(
                children: [
                  Text(greeting,
                      style: _cute(size: 22, color: const Color(0xFF6B21A8))),
                  const SizedBox(height: 2),
                  Text(title,
                      style: _cute(
                        size: 30,
                        weight: FontWeight.w900,
                        color: const Color(0xFF1B2541),
                        shadows: const [
                          Shadow(
                              offset: Offset(2, 2),
                              blurRadius: 4,
                              color: Colors.black26)
                        ],
                      ),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: _cute(
                          size: 14,
                          weight: FontWeight.w500,
                          color: Colors.black54),
                      textAlign: TextAlign.center),
                ],
              ),
            ),

            /// Emotion grid — sized to actual available space, no clipping
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Compute cell dimensions from BOTH width and height to guarantee fit
                  final availableWidth = constraints.maxWidth - 16 * 2;
                  final availableHeight = constraints.maxHeight -
                      8 -
                      80; // 80 = button overlay clearance
                  final cellWidth = (availableWidth - 8 * 3) / 4;
                  final cellHeight = (availableHeight - 8) / 2;
                  final emojiSize = cellHeight * 0.40;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: cellWidth / cellHeight,
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
                            scale: isSelected
                                ? 1.0 + _pulseCtrl.value * 0.04
                                : 1.0,
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
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      isSelected ? Colors.yellow : Colors.white,
                                  width: isSelected ? 3.5 : 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: bg.withValues(
                                        alpha: isSelected ? 0.65 : 0.3),
                                    blurRadius: isSelected ? 20 : 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(e.emoji,
                                            style:
                                                TextStyle(fontSize: emojiSize)),
                                        const SizedBox(height: 2),
                                        Text(
                                          e.name,
                                          style: _cute(
                                            size: 30,
                                            weight: FontWeight.w800,
                                            color: isAssigned
                                                ? Colors.white
                                                : Colors.black54,
                                            shadows: isAssigned
                                                ? const [
                                                    Shadow(
                                                        offset: Offset(1, 1),
                                                        blurRadius: 3,
                                                        color: Colors.black26)
                                                  ]
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isAssigned)
                                    Positioned(
                                      top: 5,
                                      right: 5,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.7),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.palette_rounded,
                                            size: 12, color: Color(0xFF6B21A8)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        // Continue button overlay
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: _selectedEmotion != null ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: Center(
              child: SizedBox(
                width: 320,
                height: 64,
                child: ElevatedButton.icon(
                  onPressed: _selectedEmotion == null || _busy
                      ? null
                      : () {
                          final e = _selectedEmotion!;
                          final isAssigned = _assignedIds.contains(e.id);
                          if (widget.mode == HowIFeelMode.end) {
                            setState(() {
                              _shuffledPalette = [..._palette]..shuffle();
                              _phase = _Phase.colorForSelected;
                            });
                          } else if (!isAssigned) {
                            setState(() {
                              _shuffledPalette = [..._palette]..shuffle();
                              _phase = _Phase.colorForSelected;
                            });
                          } else {
                            _afterSelectedHandled();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedEmotion != null
                        ? _cardBg(_selectedEmotion!)
                        : Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)),
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 3, color: Colors.white))
                      : const Icon(Icons.arrow_forward_rounded, size: 28),
                  label: Text(
                    widget.mode == HowIFeelMode.start ? 'Continue' : 'Done',
                    style: _cute(size: 24, weight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
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
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Color(0xFF6B21A8), size: 30),
              ),
            ),
          ),
      ],
    );
  }

  // ── Phase 2: inline colour picker ────────────────────────────────────────

  Widget _buildColorBubble(Color c) {
    final isChosen = _pickedColor?.toARGB32() == c.toARGB32();
    return GestureDetector(
      onTap: () {
        setState(() {
          _pickedColor = c;
          _flushColor = c;
        });
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) setState(() => _flushColor = null);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: isChosen ? 80 : 72,
        height: isChosen ? 80 : 72,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          // Always visible outline — white inner + dark outer so any color pops
          border: Border.all(
            color: isChosen ? Colors.white : Colors.white,
            width: isChosen ? 5 : 3,
          ),
          boxShadow: [
            // Dark outer ring so light colors (yellow/green) are always visible
            BoxShadow(
              color: Colors.black.withValues(alpha: isChosen ? 0.35 : 0.20),
              blurRadius: isChosen ? 16 : 8,
              spreadRadius: isChosen ? 3 : 1,
            ),
            // Color glow when chosen
            if (isChosen)
              BoxShadow(
                color: c.withValues(alpha: 0.6),
                blurRadius: 24,
                spreadRadius: 4,
              ),
          ],
        ),
        child: isChosen
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 36)
            : null,
      ),
    );
  }

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
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
          child: Column(
            children: [
              Text(title,
                  style: _cute(
                      size: 44,
                      weight: FontWeight.w900,
                      color: const Color(0xFF1B2541)),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(subtitle,
                  style: _cute(
                      size: 30, weight: FontWeight.w600, color: Colors.black54),
                  textAlign: TextAlign.center),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Big colour preview circle with emoji — bigger and more eye-catching
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            color: _pickedColor ?? _unassignedBg,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 8),
            boxShadow: [
              BoxShadow(
                color: (_pickedColor ?? _unassignedBg).withValues(alpha: 0.55),
                blurRadius: 44,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Center(
            child: Text(emotion.emoji, style: const TextStyle(fontSize: 120)),
          ),
        ),
        const SizedBox(height: 32),

        // 9-colour sensory palette — 5 top row, 4 bottom row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Row 1 — first 5 colors (shuffled)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (i) {
                  final c = _shuffledPalette[i];
                  return _buildColorBubble(c);
                }),
              ),
              const SizedBox(height: 16),
              // Row 2 — last 4 colors (shuffled), centered
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(width: 36),
                  ...List.generate(4, (i) {
                    final c = _shuffledPalette[i + 5];
                    return _buildColorBubble(c);
                  }),
                  const SizedBox(width: 36),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Confirm button — bigger and more prominent
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: SizedBox(
            width: 460,
            height: 70,
            child: ElevatedButton.icon(
              onPressed: _pickedColor == null || _busy ? null : onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: _pickedColor ?? Colors.grey.shade300,
                disabledBackgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.white,
                elevation: _pickedColor != null ? 8 : 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                          strokeWidth: 3, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 34),
              label: Stack(
                children: [
                  // Outline layer
                  Text(
                    "That's my colour! ✓",
                    style: _cute(size: 30, weight: FontWeight.w800).copyWith(
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 3
                        ..color = Colors.black.withValues(alpha: 0.3),
                    ),
                  ),
                  // Fill layer
                  Text(
                    "That's my colour! ✓",
                    style: _cute(size: 30, weight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
