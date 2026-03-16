import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/logic/adaptive_engine.dart';
import '../core/services/star_service.dart';
import '../core/widgets/star_reward_widget.dart';
import '../features/child/presentation/help_button.dart';
import '../features/child/presentation/activity_exit_handler.dart';

/// Game 5 — Calm Choice Garden: Time-Based Growth Game
///
/// Grow a calming garden through gentle taps. No win/lose condition.
/// Garden state persists across sessions. Stars for engagement, return,
/// and calm tapping.
class CalmGardenScreen extends StatefulWidget {
  const CalmGardenScreen({super.key});

  @override
  State<CalmGardenScreen> createState() => _CalmGardenScreenState();
}

class _CalmGardenScreenState extends State<CalmGardenScreen>
    with TickerProviderStateMixin {
  final Random _rng = Random();
  final AdaptiveEngine _engine = AdaptiveEngine(
    overloadTapsPerSecond: 5.0,
  );

  // Garden elements
  List<_GardenItem> _items = [];
  bool _isPaused = false;

  // Timing
  late DateTime _sessionStart;
  bool _star1Given = false; // 2 min interaction
  bool _star3Given = false; // stable tap rate

  // Persistence
  static const _prefKey = 'calm_garden_items';
  static const _prefLastDay = 'calm_garden_last_day';

  // Palette for garden elements
  static const List<Map<String, dynamic>> _palette = [
    {'emoji': '🌸', 'label': 'Cherry Blossom'},
    {'emoji': '🌻', 'label': 'Sunflower'},
    {'emoji': '🌿', 'label': 'Fern'},
    {'emoji': '🍀', 'label': 'Clover'},
    {'emoji': '🌺', 'label': 'Hibiscus'},
    {'emoji': '🦋', 'label': 'Butterfly'},
    {'emoji': '🐌', 'label': 'Snail'},
    {'emoji': '🌷', 'label': 'Tulip'},
    {'emoji': '🌼', 'label': 'Daisy'},
    {'emoji': '🍃', 'label': 'Leaf'},
    {'emoji': '🌾', 'label': 'Grain'},
    {'emoji': '🐞', 'label': 'Ladybug'},
  ];

  late AnimationController _swayController;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _swayController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _sessionStart = DateTime.now();
    _loadGarden();
    _checkDailyReturn();
    _tickTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _checkTimeStar());
  }

  @override
  void dispose() {
    _swayController.dispose();
    _tickTimer?.cancel();
    _saveGarden();
    super.dispose();
  }

  // ── Persistence ──
  Future<void> _loadGarden() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefKey) ?? [];
    setState(() {
      _items = raw
          .map((s) {
            final parts = s.split('|');
            if (parts.length >= 4) {
              return _GardenItem(
                emoji: parts[0],
                x: double.tryParse(parts[1]) ?? _rng.nextDouble(),
                y: double.tryParse(parts[2]) ?? _rng.nextDouble(),
                scale: double.tryParse(parts[3]) ?? 1.0,
              );
            }
            return null;
          })
          .whereType<_GardenItem>()
          .toList();
    });
  }

  Future<void> _saveGarden() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _items
        .map((i) =>
            '${i.emoji}|${i.x.toStringAsFixed(3)}|${i.y.toStringAsFixed(3)}|${i.scale.toStringAsFixed(2)}')
        .toList();
    await prefs.setStringList(_prefKey, data);
  }

  Future<void> _checkDailyReturn() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastDay = prefs.getString(_prefLastDay);
    if (lastDay != null && lastDay != today) {
      // Returning on a new day!
      StarService.addStars(StarService.calmGarden, 1);
      if (mounted) StarRewardWidget.show(context);
    }
    await prefs.setString(_prefLastDay, today);
  }

  void _checkTimeStar() {
    if (!_star1Given) {
      final elapsed = DateTime.now().difference(_sessionStart).inSeconds;
      if (elapsed >= 120) {
        _star1Given = true;
        StarService.addStars(StarService.calmGarden, 1);
        if (mounted) StarRewardWidget.show(context);
      }
    }
  }

  // ── Tap ──
  void _onGardenTap(TapDownDetails details, BoxConstraints constraints) {
    _engine.recordTap();

    if (_engine.isOverloaded) {
      setState(() => _isPaused = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isPaused = false);
      });
      return;
    }

    if (_isPaused) return;

    final pal = _palette[_rng.nextInt(_palette.length)];
    final x = details.localPosition.dx / constraints.maxWidth;
    final y = details.localPosition.dy / constraints.maxHeight;
    final scale = 0.8 + _rng.nextDouble() * 0.5;

    setState(() {
      _items.add(
          _GardenItem(emoji: pal['emoji'] as String, x: x, y: y, scale: scale));
    });
    _saveGarden();

    // Check stable tap star (if we've been going 2+ min without overload)
    if (!_star3Given && _star1Given && !_engine.isOverloaded) {
      _star3Given = true;
      StarService.addStars(StarService.calmGarden, 1);
      if (mounted) StarRewardWidget.show(context);
    }
  }

  // ── UI ──
  TextStyle _cute(
          {double sz = 24,
          Color c = Colors.white,
          FontWeight fw = FontWeight.w700}) =>
      GoogleFonts.baloo2(fontSize: sz, fontWeight: fw, color: c);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9), Color(0xFFA5D6A7)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Garden area
              LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onTapDown: (d) => _onGardenTap(d, constraints),
                    behavior: HitTestBehavior.opaque,
                    child: Stack(
                      children: [
                        // Background grass
                        const Positioned.fill(child: SizedBox()),
                        // Items
                        ..._items.map((item) {
                          return Positioned(
                            left: item.x * constraints.maxWidth - 24,
                            top: item.y * constraints.maxHeight - 24,
                            child: AnimatedBuilder(
                              animation: _swayController,
                              builder: (context, child) {
                                final sway = sin(
                                        _swayController.value * pi * 2 +
                                            item.x * 10) *
                                    3;
                                return Transform.translate(
                                  offset: Offset(sway, 0),
                                  child: Transform.scale(
                                      scale: item.scale, child: child),
                                );
                              },
                              child: Text(item.emoji,
                                  style: const TextStyle(fontSize: 40)),
                            ),
                          );
                        }),
                        // Paused overlay
                        if (_isPaused)
                          Positioned.fill(
                            child: Container(
                              color: Colors.white.withValues(alpha: 0.5),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🌬️',
                                        style: TextStyle(fontSize: 60)),
                                    const SizedBox(height: 10),
                                    Text('Take a breath…',
                                        style: _cute(
                                            sz: 26,
                                            c: const Color(0xFF2E7D32))),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              // Header
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🌱', style: TextStyle(fontSize: 28)),
                        const SizedBox(width: 8),
                        Text('My Garden',
                            style: _cute(sz: 24, c: const Color(0xFF2E7D32))),
                        const SizedBox(width: 10),
                        Text('${_items.length}',
                            style: _cute(sz: 20, c: const Color(0xFF558B2F))),
                      ],
                    ),
                  ),
                ),
              ),
              // Back
              Positioned(top: 10, left: 10, child: _backButton()),
              // UCD015: Help button
              const Positioned(
                top: 10,
                right: 10,
                child: HelpButton(
                  activityId: 'game_calm_garden',
                  activityEmoji: '🌱',
                  activityName: 'Calm Garden',
                ),
              ),
              // Hint
              if (_items.isEmpty)
                Positioned.fill(
                  child: Center(
                    child: Text('Tap anywhere to plant 🌸',
                        style: _cute(
                            sz: 28,
                            c: const Color(0xFF2E7D32).withValues(alpha: 0.6))),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _backButton() => GestureDetector(
        onTap: () => ActivityExitHandler.handleExitActivity(
          context: context,
          activityId: 'game_calm_garden',
          activityEmoji: '🌱',
          buildProgressData: () => {
            'itemCount': _items.length,
          },
          onBeforeExit: _saveGarden,
        ),
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
              color: Color(0xFF2E7D32), size: 28),
        ),
      );
}

class _GardenItem {
  final String emoji;
  final double x;
  final double y;
  final double scale;
  _GardenItem(
      {required this.emoji,
      required this.x,
      required this.y,
      this.scale = 1.0});
}
