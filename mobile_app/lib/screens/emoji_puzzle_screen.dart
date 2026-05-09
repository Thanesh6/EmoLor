import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/data/game_emojis.dart';
import '../core/services/star_service.dart';
import '../core/widgets/star_reward_widget.dart';
import '../features/child/presentation/help_button.dart';
import '../features/child/presentation/activity_exit_handler.dart';
import '../features/child/models/activity_save_state.dart';
import '../features/child/services/activity_progress_service.dart';
import '../core/services/emotion_journal_service.dart';
import '../core/services/audio_service.dart';

/// Emoji Puzzle — A jigsaw-style game where children drag emoji pieces
/// into the correct grid positions to complete a large emoji image.
class EmojiPuzzleScreen extends StatefulWidget {
  const EmojiPuzzleScreen({super.key});

  @override
  State<EmojiPuzzleScreen> createState() => _EmojiPuzzleScreenState();
}

class _EmojiPuzzleScreenState extends State<EmojiPuzzleScreen>
    with TickerProviderStateMixin {
  static const String _activityId = 'game_emoji_puzzle';
  // Feelings first, then the rest — so puzzles start with core facial emojis
  static final List<Map<String, dynamic>> _puzzles = [
    ...GameEmojis.byCategory('feelings').map((e) => e.toMap()),
    ...GameEmojis.all
        .where((e) => e.category != 'feelings')
        .map((e) => e.toMap()),
  ];

  static const int _gridSize = 3; // 3x3 puzzle
  static const int _totalPieces = _gridSize * _gridSize;

  final Stopwatch _stopwatch = Stopwatch();
  int _currentPuzzle = 0;
  int _sessionStars = 0;
  bool _showComplete = false;
  final ActivityProgressService _progressService = ActivityProgressService();

// Adaptive heuristic: track which pieces the child has misplaced.
  // Hint shows only for a piece that has erred before, and only while it's being dragged.
  final Set<int> _erroredPieces = {};

  // Pulse animation for hint slot
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Each piece has a correct index (0..8) and is either placed or in the tray
  late List<int> _trayPieces; // piece indices still in tray (shuffled)
  late List<int?> _boardSlots; // boardSlots[gridIndex] = pieceIndex or null
  int? _draggedPiece;
  int? _hoveredSlot;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _setupPuzzle();
    _stopwatch.start();
    _restoreProgress();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _restoreProgress() async {
    final saved = await _progressService.loadProgress(_activityId);
    if (!mounted || saved == null) return;

    final data = saved.progressData;
    final savedPuzzle = data['currentPuzzle'];

    if (savedPuzzle is! int) return;
    if (savedPuzzle < 0 || savedPuzzle >= _puzzles.length) return;

    // Resume at saved puzzle level, restart puzzle fresh (no mid-puzzle state)
    setState(() {
      _currentPuzzle = savedPuzzle;
      _sessionStars = 0; // always start session at 0
    });
    _setupPuzzle();
  }

  Map<String, dynamic> _buildProgressData() {
    return {
      'currentPuzzle': _currentPuzzle,
    };
  }

  Future<void> _saveProgress() async {
    await _progressService.saveProgress(
      ActivitySaveState(
        activityId: _activityId,
        savedAt: DateTime.now(),
        elapsedSeconds: 0,
        progressData: _buildProgressData(),
      ),
    );
  }

  Future<void> _handleReturnPressed() async {
    await ActivityExitHandler.handleExitActivity(
      context: context,
      activityId: _activityId,
      activityName: 'EMOZZLE',
      activityEmoji: '🧩',
      buildProgressData: _buildProgressData,
      starGameKey: StarService.emojiPuzzle,
      sessionStars: _sessionStars,
      elapsedSeconds: _stopwatch.elapsed.inSeconds,
    );
  }

  void _setupPuzzle() {
    _showComplete = false;
    _draggedPiece = null;
    _hoveredSlot = null;
    _erroredPieces.clear(); // reset per-piece errors for new level
    // All pieces start in tray, shuffled
    _trayPieces = List.generate(_totalPieces, (i) => i);
    _trayPieces.shuffle(Random());
    _boardSlots = List.filled(_totalPieces, null);
    setState(() {});
  }

  void _onPiecePlaced(int pieceIndex, int slotIndex) {
    if (pieceIndex == slotIndex) {
      // Correct placement!
      AudioService.instance.playSfx(SoundEffect.snap);
      setState(() {
        _boardSlots[slotIndex] = pieceIndex;
        _trayPieces.remove(pieceIndex);
        _draggedPiece = null;
        _hoveredSlot = null;
      });

      // Check if puzzle complete
      if (_trayPieces.isEmpty) {
        _onPuzzleComplete();
      }
    } else {
      // Wrong slot — bounce back and remember THIS piece erred
      AudioService.instance.playSfx(SoundEffect.wrong);
      setState(() {
        _erroredPieces.add(pieceIndex);
        _draggedPiece = null;
        _hoveredSlot = null;
      });
    }
  }

  void _onPuzzleComplete() {
    AudioService.instance.playSfx(SoundEffect.complete);
    setState(() => _showComplete = true);
    _sessionStars++;

    final puzzle = _puzzles[_currentPuzzle];
    EmotionJournalService.log(
      emoji: puzzle['emoji'] as String,
      emotionName: puzzle['name'] as String,
      category: puzzle['category'] as String,
      gameId: _activityId,
    );

    Future.delayed(const Duration(milliseconds: 1500), () async {
      if (!mounted) return;
      StarRewardWidget.show(context);
      if (_currentPuzzle + 1 >= _puzzles.length) {
        // All puzzles done — restart from beginning
        setState(() => _currentPuzzle = 0);
      } else {
        setState(() => _currentPuzzle++);
      }
      _setupPuzzle();
      await _saveProgress();
    });
  }

  TextStyle _cute(
          {double sz = 24,
          Color c = Colors.white,
          FontWeight fw = FontWeight.w700}) =>
      GoogleFonts.baloo2(fontSize: sz, fontWeight: fw, color: c);

  @override
  Widget build(BuildContext context) {
    final puzzle = _puzzles[_currentPuzzle];
    final emoji = puzzle['emoji'] as String;
    final name = puzzle['name'] as String;
    final color = puzzle['color'] as Color;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _handleReturnPressed();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF0FFF4), Color(0xFFECFDF5), Color(0xFFD1FAE5)],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    const SizedBox(height: 104),
                    // Puzzle board
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: _buildPuzzleBoard(emoji, color),
                      ),
                    ),
                    // Piece tray
                    SizedBox(
                      height: 184,
                      child: _buildPieceTray(emoji, color),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
                // Back button
                Positioned(
                  top: 10,
                  left: 10,
                  child: GestureDetector(
                    onTap: _handleReturnPressed,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 32),
                    ),
                  ),
                ),
                // Banner
                Positioned(
                  top: 14,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 31),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(31),
                        border: Border.all(
                            color: color.withValues(alpha: 0.5), width: 3),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🧩 Build: ',
                              style: _cute(
                                  sz: 29,
                                  fw: FontWeight.w900,
                                  c: Colors.black87)),
                          Text(emoji, style: const TextStyle(fontSize: 38)),
                          const SizedBox(width: 6),
                          Text(name,
                              style:
                                  _cute(sz: 29, fw: FontWeight.w900, c: color)),
                        ],
                      ),
                    ),
                  ),
                ),
                // Hint + Stars (top-right row)
                Positioned(
                  top: 14,
                  right: 16,
                  child: Row(
                    children: [
                      const HelpButton(
                        activityId: 'game_emoji_puzzle',
                        activityEmoji: '🧩',
                        activityName: 'EMOZZLE',
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 19, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B21A8),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Text('⭐ $_sessionStars', style: _cute(sz: 26)),
                      ),
                    ],
                  ),
                ),
                // Completion overlay
                if (_showComplete)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(36),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 20),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 80)),
                          const SizedBox(height: 12),
                          Text('✨ Complete! ✨',
                              style: _cute(
                                  sz: 32,
                                  fw: FontWeight.w900,
                                  c: const Color(0xFF22C55E))),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPuzzleBoard(String emoji, Color color) {
    final boardSize = min(MediaQuery.of(context).size.width * 0.86, 414.0);
    final cellSize = boardSize / _gridSize;

    return SizedBox(
      width: boardSize,
      height: boardSize,
      child: Stack(
        children: [
          // Reference emoji (faded) behind the grid
          Center(
            child: Transform.translate(
              offset: Offset(0, -boardSize * 0.015),
              child: Opacity(
                opacity: 0.12,
                child: Text(emoji,
                    style: TextStyle(fontSize: boardSize * 0.85, height: 1.0)),
              ),
            ),
          ),
          // Grid of drop targets
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _gridSize,
            ),
            itemCount: _totalPieces,
            itemBuilder: (context, slotIndex) {
              final placedPiece = _boardSlots[slotIndex];
              final isHovered =
                  _hoveredSlot == slotIndex && _boardSlots[slotIndex] == null;
              // Adaptive hint: only when the child is dragging a piece that
              // has previously been misplaced — highlight just its correct slot.
              // Pieces that haven't errored yet get no clue.
              final bool isHintSlot = _draggedPiece != null &&
                  _draggedPiece == slotIndex &&
                  _boardSlots[slotIndex] == null &&
                  _erroredPieces.contains(_draggedPiece);

              return DragTarget<int>(
                onWillAcceptWithDetails: (details) {
                  setState(() => _hoveredSlot = slotIndex);
                  return _boardSlots[slotIndex] == null;
                },
                onLeave: (_) => setState(() => _hoveredSlot = null),
                onAcceptWithDetails: (details) =>
                    _onPiecePlaced(details.data, slotIndex),
                builder: (context, candidateData, rejectedData) {
                  return ScaleTransition(
                    scale: isHintSlot
                        ? _pulseAnimation
                        : const AlwaysStoppedAnimation(1.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: placedPiece != null
                            ? color.withValues(alpha: 0.15)
                            : isHintSlot
                                ? const Color(0xFF22C55E)
                                    .withValues(alpha: 0.22)
                                : isHovered
                                    ? color.withValues(alpha: 0.25)
                                    : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isHintSlot
                              ? const Color(0xFF22C55E)
                              : isHovered
                                  ? color
                                  : placedPiece != null
                                      ? color.withValues(alpha: 0.4)
                                      : Colors.grey.shade300,
                          width: (isHovered || isHintSlot) ? 3.5 : 2,
                        ),
                        boxShadow: (isHovered || isHintSlot)
                            ? [
                                BoxShadow(
                                    color: (isHintSlot
                                            ? const Color(0xFF22C55E)
                                            : color)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 12)
                              ]
                            : [],
                      ),
                      child: placedPiece != null
                          ? _buildPieceContent(emoji, placedPiece, cellSize - 6)
                          : Center(
                              child: isHovered
                                  ? Icon(Icons.add_rounded,
                                      color: color, size: 28)
                                  : Text(
                                      '${slotIndex + 1}',
                                      style: _cute(
                                          sz: 28,
                                          c: isHintSlot
                                              ? const Color(0xFF22C55E)
                                              : Colors.grey.shade500,
                                          fw: FontWeight.w900),
                                    ),
                            ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPieceTray(String emoji, Color color) {
    if (_trayPieces.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _trayPieces.map((pieceIndex) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Draggable<int>(
                data: pieceIndex,
                onDragStarted: () => setState(() => _draggedPiece = pieceIndex),
                onDragEnd: (_) => setState(() => _draggedPiece = null),
                feedback: Material(
                  color: Colors.transparent,
                  child: _buildDragPieceWithBadge(
                      emoji, pieceIndex, 127, color, true),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: _buildDragPieceWithBadge(
                      emoji, pieceIndex, 115, color, false),
                ),
                child: _buildDragPieceWithBadge(
                    emoji, pieceIndex, 115, color, false),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDragPiece(
      String emoji, int pieceIndex, double size, Color color, bool isDragging) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDragging ? color : color.withValues(alpha: 0.5),
          width: isDragging ? 3.5 : 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDragging
                ? color.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.1),
            blurRadius: isDragging ? 16 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildPieceContent(emoji, pieceIndex, size - 5),
      ),
    );
  }

  /// Wraps a drag piece with a number badge when the piece has previously errored
  Widget _buildDragPieceWithBadge(
      String emoji, int pieceIndex, double size, Color color, bool isDragging) {
    final hasErrored = _erroredPieces.contains(pieceIndex);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildDragPiece(emoji, pieceIndex, size, color, isDragging),
        if (hasErrored)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4),
                ],
              ),
              child: Center(
                child: Text(
                  '${pieceIndex + 1}',
                  style: GoogleFonts.baloo2(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPieceContent(String emoji, int pieceIndex, double cellSize) {
    // Show a cropped portion of the emoji using alignment
    final row = pieceIndex ~/ _gridSize;
    final col = pieceIndex % _gridSize;
    // Map piece position to alignment — no extra shift so pieces align correctly
    final alignX = (col - (_gridSize - 1) / 2) / ((_gridSize - 1) / 2);
    final alignY = (row - (_gridSize - 1) / 2) / ((_gridSize - 1) / 2);
    final emojiSize = cellSize * _gridSize * 0.85;
    // Shift emoji text up slightly to compensate for built-in descent/padding
    final upShift = emojiSize * 0.02;

    return SizedBox(
      width: cellSize,
      height: cellSize,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: cellSize * _gridSize,
          maxHeight: cellSize * _gridSize,
          alignment: Alignment(alignX, alignY),
          child: Transform.translate(
            offset: Offset(0, -upShift),
            child: Text(
              emoji,
              style: TextStyle(fontSize: emojiSize, height: 1.0),
            ),
          ),
        ),
      ),
    );
  }
}
