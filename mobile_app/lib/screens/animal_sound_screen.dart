import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/star_service.dart';
import '../core/widgets/star_reward_widget.dart';
import '../features/child/presentation/help_button.dart';
import '../features/child/presentation/activity_exit_handler.dart';
import '../features/child/services/activity_progress_service.dart';
import '../core/services/audio_service.dart';

/// ANIMATCH — two modes:
///   Emoji Mode : animal emoji + name shown → tap the correct sound from 4 options
///   Voice Mode : animal sound plays → tap the correct animal from 4 emoji cards
class AnimalSoundScreen extends StatefulWidget {
  const AnimalSoundScreen({super.key});

  @override
  State<AnimalSoundScreen> createState() => _AnimalSoundScreenState();
}

class _AnimalSoundScreenState extends State<AnimalSoundScreen>
    with TickerProviderStateMixin {
  static const String _activityId = 'game_animal_sound';
  final ActivityProgressService _progressService = ActivityProgressService();
  final Random _rng = Random();
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _animalPlayer = AudioPlayer();

  static const List<Map<String, String>> _animals = [
    {'emoji': '🐶', 'name': 'Dog',      'sound': 'Woof',       'file': 'dog.mp3'},
    {'emoji': '🐱', 'name': 'Cat',      'sound': 'Meow',       'file': 'cat.mp3'},
    {'emoji': '🐮', 'name': 'Cow',      'sound': 'Moo',        'file': 'cow.mp3'},
    {'emoji': '🐷', 'name': 'Pig',      'sound': 'Oink',       'file': 'pig.mp3'},
    {'emoji': '🐸', 'name': 'Frog',     'sound': 'Ribbit',     'file': 'frog.mp3'},
    {'emoji': '🦆', 'name': 'Duck',     'sound': 'Quack',      'file': 'duck.mp3'},
    {'emoji': '🦁', 'name': 'Lion',     'sound': 'Roar',       'file': 'lion.mp3'},
    {'emoji': '🐘', 'name': 'Elephant', 'sound': 'Trumpet',    'file': 'elephant.mp3'},
    {'emoji': '🐴', 'name': 'Horse',    'sound': 'Neigh',      'file': 'horse.mp3'},
    {'emoji': '🐑', 'name': 'Sheep',    'sound': 'Baa',        'file': 'sheep.mp3'},
    {'emoji': '🐺', 'name': 'Wolf',     'sound': 'Howl',       'file': 'wolf.mp3'},
    {'emoji': '🐝', 'name': 'Bee',      'sound': 'Buzz',       'file': 'bee.mp3'},
    {'emoji': '🐓', 'name': 'Rooster',  'sound': 'Cock a doo', 'file': 'rooster.mp3'},
    {'emoji': '🐻', 'name': 'Bear',     'sound': 'Growl',      'file': 'bear.mp3'},
    {'emoji': '🦊', 'name': 'Fox',      'sound': 'Yip',        'file': 'fox.mp3'},
    {'emoji': '🐔', 'name': 'Chicken',  'sound': 'Cluck',      'file': 'chicken.mp3'},
    {'emoji': '🐦', 'name': 'Bird',     'sound': 'Tweet',      'file': 'bird.mp3'},
    {'emoji': '🫏', 'name': 'Donkey',   'sound': 'Hee-haw',    'file': 'donkey.mp3'},
    {'emoji': '🐐', 'name': 'Goat',     'sound': 'Maa',        'file': 'goat.mp3'},
    {'emoji': '🐒', 'name': 'Monkey',   'sound': 'Ooh ooh',    'file': 'monkey.mp3'},
    {'emoji': '🐯', 'name': 'Tiger',    'sound': 'Roar',       'file': 'tiger.mp3'},
    {'emoji': '🐍', 'name': 'Snake',    'sound': 'Hiss',       'file': 'snake.mp3'},
  ];

  // ── Mode ──────────────────────────────────────────────────────────────────
  bool _isVoiceMode = false;

  // ── Shared ────────────────────────────────────────────────────────────────
  late List<Map<String, String>> _shuffledAnimals;
  int _currentIndex = 0;
  int _sessionStars = 0;

  // ── Emoji Mode state ──────────────────────────────────────────────────────
  List<String> _soundChoices = [];
  String? _selectedSound;
  bool _showFeedback = false;
  bool _feedbackCorrect = false;

  // ── Voice Mode state ──────────────────────────────────────────────────────
  List<Map<String, String>> _animalChoices = []; // 4 animal options
  int _voiceCorrectIdx = 0;
  int? _voiceTappedIdx;
  bool _voiceAnswered = false;
  bool _voiceRevealHint = false;
  int _voiceAttempts = 0;
  final List<bool> _voiceFlashRed = [false, false, false, false];
  bool _isPlayingSound = false;

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _bounceController;
  late AnimationController _shakeController;
  late AnimationController _enterController;
  late Animation<double> _enterAnim;
  late AnimationController _hintController;
  late AnimationController _speakerController;
  late AnimationController _voiceCorrectPulseController;
  late Animation<double> _voiceCorrectPulseAnim;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _enterController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _enterAnim =
        CurvedAnimation(parent: _enterController, curve: Curves.elasticOut);
    _hintController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _speakerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _voiceCorrectPulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _voiceCorrectPulseAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.13), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.13, end: 0.95), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(
        parent: _voiceCorrectPulseController, curve: Curves.easeInOut));

    // Use transient-duck focus so the bg music ducks briefly instead of stopping.
    _animalPlayer.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.game,
      ),
    ));

    _initTts();
    _shuffledAnimals = List.from(_animals)..shuffle(_rng);
    _loadEmojiQuestion();
    _restoreProgress();
  }

  @override
  void dispose() {
    _tts.stop();
    _animalPlayer.dispose();
    _bounceController.dispose();
    _shakeController.dispose();
    _enterController.dispose();
    _hintController.dispose();
    _speakerController.dispose();
    _voiceCorrectPulseController.dispose();
    super.dispose();
  }

  // ── TTS ───────────────────────────────────────────────────────────────────

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.4);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isPlayingSound = false);
      _speakerController.stop();
      _speakerController.reset();
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _isPlayingSound = false);
      _speakerController.stop();
      _speakerController.reset();
    });
    final raw = await _tts.getVoices;
    if (raw is List) {
      final voices = raw.cast<Map>();
      final female = voices.where((v) {
        final name = (v['name'] as String? ?? '').toLowerCase();
        final gender = (v['gender'] as String? ?? '').toLowerCase();
        return gender == 'female' ||
            name.contains('female') ||
            name.contains('samantha') ||
            name.contains('karen') ||
            name.contains('moira') ||
            name.contains('victoria') ||
            name.contains('zira');
      }).firstOrNull;
      if (female != null) {
        await _tts.setVoice({
          'name': female['name'] as String,
          'locale': (female['locale'] as String? ?? 'en-US'),
        });
      }
    }
  }

  /// Play MP3 file for [animal]; fall back to TTS of its sound word.
  Future<void> _playAnimalSound(Map<String, String> animal,
      {bool isTtsSpeak = false}) async {
    final file = animal['file'];
    if (!isTtsSpeak && file != null) {
      try {
        await _animalPlayer.stop();
        await _animalPlayer.play(AssetSource('audio/animals/$file'));
        setState(() => _isPlayingSound = true);
        _speakerController.repeat(reverse: true);
        _animalPlayer.onPlayerComplete.first.then((_) {
          if (mounted) setState(() => _isPlayingSound = false);
          _speakerController.stop();
          _speakerController.reset();
        }).catchError((_) {});
        return;
      } catch (_) {}
    }
    await _tts.stop();
    final sound = animal['sound'] ?? '';
    await _tts.speak(sound.replaceAll('!', '').trim());
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Map<String, String> get _currentAnimal =>
      _shuffledAnimals[_currentIndex % _shuffledAnimals.length];

  Future<void> _restoreProgress() async {
    final saved = await _progressService.loadProgress(_activityId);
    if (!mounted || saved == null) return;
    final data = saved.progressData;
    final savedIndex = data['currentIndex'];
    if (savedIndex is! int) return;
    setState(() {
      _currentIndex = savedIndex.clamp(0, _shuffledAnimals.length - 1);
      _sessionStars = 0;
    });
    _isVoiceMode ? _loadVoiceQuestion() : _loadEmojiQuestion();
  }

  Map<String, dynamic> _buildProgressData() => {'currentIndex': _currentIndex};

  Future<void> _handleReturnPressed() async {
    await _tts.stop();
    await _animalPlayer.stop();
    await ActivityExitHandler.handleExitActivity(
      context: context,
      activityId: _activityId,
      activityName: 'ANIMATCH',
      activityEmoji: '🐾',
      buildProgressData: _buildProgressData,
      starGameKey: StarService.animalSound,
      sessionStars: _sessionStars,
    );
  }

  void _switchMode(bool voiceMode) {
    if (_isVoiceMode == voiceMode) return;
    _tts.stop();
    _animalPlayer.stop();
    _hintController.stop();
    _hintController.reset();
    _speakerController.stop();
    _speakerController.reset();
    setState(() {
      _isVoiceMode = voiceMode;
      _isPlayingSound = false;
    });
    voiceMode ? _loadVoiceQuestion(autoPlay: true) : _loadEmojiQuestion();
  }

  void _advanceAnimal() {
    _currentIndex++;
    if (_currentIndex >= _shuffledAnimals.length) {
      _shuffledAnimals = List.from(_animals)..shuffle(_rng);
      _currentIndex = 0;
    }
  }

  // ── Emoji Mode ────────────────────────────────────────────────────────────

  void _loadEmojiQuestion() {
    final correct = _currentAnimal['sound']!;
    final pool = _animals.map((a) => a['sound']!).where((s) => s != correct).toList()
      ..shuffle(_rng);
    _soundChoices = [correct, ...pool.take(3)]..shuffle(_rng);
    _selectedSound = null;
    _showFeedback = false;
    _feedbackCorrect = false;
    _enterController.forward(from: 0);
    setState(() {});
  }

  void _onSoundChoiceTap(String sound) {
    if (_showFeedback) return;
    setState(() => _selectedSound = sound);
    // Play the tapped sound
    final animal = _animals.firstWhere((a) => a['sound'] == sound, orElse: () => {});
    if (animal.isNotEmpty) _playAnimalSound(animal);
  }

  void _onConfirm() {
    if (_selectedSound == null || _showFeedback) return;
    final isCorrect = _selectedSound == _currentAnimal['sound'];
    setState(() {
      _showFeedback = true;
      _feedbackCorrect = isCorrect;
    });

    if (isCorrect) {
      AudioService.instance.playSfx(SoundEffect.correct);
      _bounceController.forward(from: 0);
      _sessionStars++;
      Future.delayed(const Duration(milliseconds: 1000), () async {
        if (!mounted) return;
        await _animalPlayer.stop();
        await _tts.stop();
        StarRewardWidget.show(context);
        _advanceAnimal();
        _loadEmojiQuestion();
      });
    } else {
      AudioService.instance.playSfx(SoundEffect.wrong);
      _shakeController.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 1000), () async {
        if (!mounted) return;
        await _animalPlayer.stop();
        await _tts.stop();
        setState(() {
          _selectedSound = null;
          _showFeedback = false;
        });
      });
    }
  }

  // ── Voice Mode ────────────────────────────────────────────────────────────

  void _loadVoiceQuestion({bool autoPlay = false}) {
    final correct = _currentAnimal;
    final pool = _animals.where((a) => a['name'] != correct['name']).toList()
      ..shuffle(_rng);
    _animalChoices = [correct, ...pool.take(3)]..shuffle(_rng);
    _voiceCorrectIdx =
        _animalChoices.indexWhere((a) => a['name'] == correct['name']);
    _voiceTappedIdx = null;
    _voiceAnswered = false;
    _voiceRevealHint = false;
    _voiceAttempts = 0;
    for (int i = 0; i < 4; i++) _voiceFlashRed[i] = false;
    _hintController.stop();
    _hintController.reset();
    _enterController.forward(from: 0);
    setState(() {});

    if (autoPlay) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _playAnimalSound(_currentAnimal);
      });
    }
  }

  void _onVoiceAnimalTap(int index) {
    if (_voiceAnswered) return;
    final isCorrect = index == _voiceCorrectIdx;

    if (_voiceRevealHint) {
      if (!isCorrect) return;
      _hintController.stop();
      _voiceAdvanceCorrect();
      return;
    }

    setState(() => _voiceTappedIdx = index);

    if (isCorrect) {
      _voiceAdvanceCorrect();
    } else {
      _voiceAttempts++;
      AudioService.instance.playSfx(SoundEffect.wrong);
      setState(() => _voiceFlashRed[index] = true);
      _shakeController.forward(from: 0);

      if (_voiceAttempts >= 2) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          setState(() {
            _voiceRevealHint = true;
            _voiceTappedIdx = null;
            _voiceFlashRed[index] = false;
          });
          _hintController.repeat(reverse: true);
        });
      } else {
        Future.delayed(const Duration(milliseconds: 700), () {
          if (!mounted) return;
          setState(() {
            _voiceTappedIdx = null;
            _voiceFlashRed[index] = false;
          });
        });
      }
    }
  }

  void _voiceAdvanceCorrect() {
    setState(() => _voiceAnswered = true);
    AudioService.instance.playSfx(SoundEffect.correct);
    _voiceCorrectPulseController.forward(from: 0);
    _bounceController.forward(from: 0);
    _sessionStars++;
    StarRewardWidget.show(context);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _animalPlayer.stop();
      _tts.stop();
      setState(() => _isPlayingSound = false);
      _speakerController.stop();
      _speakerController.reset();
      _advanceAnimal();
      _loadVoiceQuestion(autoPlay: true);
    });
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  TextStyle _cute(
          {double sz = 24,
          Color c = Colors.white,
          FontWeight fw = FontWeight.w700}) =>
      GoogleFonts.baloo2(fontSize: sz, fontWeight: fw, color: c);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _handleReturnPressed();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF3E8FF), Color(0xFFEDE9FE), Color(0xFFE0F2FE)],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                _isVoiceMode ? _buildVoiceMode() : _buildEmojiMode(),

                // ── Banner ───────────────────────────────────────────
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 22),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7E6).withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.7),
                            width: 2.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isVoiceMode
                                ? '🔊 Voice: Which animal?'
                                : '🐾 Match: What sound?',
                            style: _cute(
                                sz: 24,
                                fw: FontWeight.w900,
                                c: const Color(0xFF6B21A8)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Top-right: Help + Stars ──────────────────────────
                Positioned(
                  top: 14,
                  right: 16,
                  child: Row(
                    children: [
                      const HelpButton(
                        activityId: 'game_animal_sound',
                        activityEmoji: '🐾',
                        activityName: 'ANIMATCH',
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B21A8),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text('⭐ $_sessionStars',
                            style: _cute(sz: 22)),
                      ),
                    ],
                  ),
                ),

                // ── Back button ──────────────────────────────────────
                Positioned(
                  top: 20,
                  left: 20,
                  child: GestureDetector(
                    onTap: _handleReturnPressed,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 30),
                    ),
                  ),
                ),

                // ── Mode toggle pill ─────────────────────────────────
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                            width: 1.5),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFF6B21A8).withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildModeTab(
                              label: '🐾  Emoji Mode',
                              active: !_isVoiceMode,
                              onTap: () => _switchMode(false)),
                          _buildModeTab(
                              label: '🔊  Voice Mode',
                              active: _isVoiceMode,
                              onTap: () => _switchMode(true)),
                        ],
                      ),
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

  Widget _buildModeTab(
      {required String label,
      required bool active,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF6B21A8) : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          label,
          style: _cute(
            sz: 14,
            fw: FontWeight.w800,
            c: active ? Colors.white : const Color(0xFF6B21A8),
          ),
        ),
      ),
    );
  }

  // ── Emoji Mode UI ─────────────────────────────────────────────────────────

  Widget _buildEmojiMode() {
    final animal = _currentAnimal;
    return Column(
      children: [
        const SizedBox(height: 90),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animal emoji + name
              ScaleTransition(
                scale: _enterAnim,
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _bounceController,
                      builder: (ctx, ch) => Transform.translate(
                        offset: Offset(0, -sin(_bounceController.value * pi) * 20),
                        child: ch,
                      ),
                      child: Text(animal['emoji']!,
                          style: const TextStyle(fontSize: 150)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      animal['name']!,
                      style: _cute(
                          sz: 42, fw: FontWeight.w900, c: const Color(0xFF4C1D95)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Text('Tap a sound to hear it, then confirm! 🔊',
                  style: _cute(sz: 20, c: const Color(0xFF6B21A8))),
              const SizedBox(height: 14),

              // 4 sound cards
              AnimatedBuilder(
                animation: _shakeController,
                builder: (ctx, ch) {
                  final shake = (!_feedbackCorrect && _showFeedback)
                      ? sin(_shakeController.value * 3 * pi) * 9
                      : 0.0;
                  return Transform.translate(offset: Offset(shake, 0), child: ch);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: IntrinsicHeight(
                    child: Row(
                      children: _soundChoices.map((s) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: _buildSoundCard(s, animal['sound']!),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Confirm button
              if (!_showFeedback)
                GestureDetector(
                  onTap: _selectedSound != null ? _onConfirm : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 48, vertical: 16),
                    decoration: BoxDecoration(
                      color: _selectedSound != null
                          ? const Color(0xFF6B21A8)
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: _selectedSound != null
                          ? [
                              BoxShadow(
                                  color: const Color(0xFF6B21A8)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6))
                            ]
                          : [],
                    ),
                    child: Text(
                      '✓  That\'s my answer!',
                      style: _cute(
                          sz: 26,
                          fw: FontWeight.w900,
                          c: _selectedSound != null
                              ? Colors.white
                              : Colors.grey.shade500),
                    ),
                  ),
                ),

              if (_showFeedback)
                Text(
                  _feedbackCorrect ? '✨ That\'s right! ✨' : '🤔 Try again!',
                  style: _cute(
                    sz: 32,
                    fw: FontWeight.w900,
                    c: _feedbackCorrect
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFEF4444),
                  ),
                ),

              const SizedBox(height: 60), // space for mode toggle
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSoundCard(String sound, String correctSound) {
    final isSelected = _selectedSound == sound;
    Color bg, border, text;

    if (!_showFeedback) {
      if (isSelected) {
        bg = const Color(0xFFEDE9FE);
        border = const Color(0xFF6B21A8);
        text = const Color(0xFF4C1D95);
      } else {
        bg = Colors.white;
        border = const Color(0xFFBB6BD9);
        text = const Color(0xFF4C1D95);
      }
    } else if (sound == correctSound) {
      bg = const Color(0xFFDCFCE7);
      border = const Color(0xFF22C55E);
      text = const Color(0xFF166534);
    } else if (sound == _selectedSound) {
      bg = const Color(0xFFFFE4E4);
      border = const Color(0xFFEF4444);
      text = const Color(0xFF991B1B);
    } else {
      bg = Colors.white.withValues(alpha: 0.4);
      border = Colors.grey.shade300;
      text = Colors.grey.shade400;
    }

    return GestureDetector(
      onTap: _showFeedback ? null : () => _onSoundChoiceTap(sound),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 90,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: isSelected ? 3.5 : 2.5),
          boxShadow: isSelected && !_showFeedback
              ? [
                  BoxShadow(
                      color: const Color(0xFF6B21A8).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🔊', style: TextStyle(fontSize: isSelected ? 22 : 18)),
            const SizedBox(height: 2),
            Text(
              sound,
              style: _cute(sz: 26, fw: FontWeight.w900, c: text),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Voice Mode UI ─────────────────────────────────────────────────────────

  Widget _buildVoiceMode() {
    return Column(
      children: [
        const SizedBox(height: 90),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated speaker + replay button
              ScaleTransition(
                scale: _enterAnim,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => _playAnimalSound(_currentAnimal),
                      child: AnimatedBuilder(
                        animation: _speakerController,
                        builder: (_, __) {
                          final scale = _isPlayingSound
                              ? 1.0 + _speakerController.value * 0.15
                              : 1.0;
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                color: _isPlayingSound
                                    ? const Color(0xFF7C3AED)
                                    : const Color(0xFFEDE9FE),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6B21A8)
                                        .withValues(alpha: _isPlayingSound ? 0.4 : 0.15),
                                    blurRadius: _isPlayingSound ? 28 : 12,
                                    spreadRadius: _isPlayingSound ? 4 : 0,
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isPlayingSound
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_up_outlined,
                                color: _isPlayingSound
                                    ? Colors.white
                                    : const Color(0xFF7C3AED),
                                size: 64,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Which animal makes this sound?',
                        style: _cute(sz: 22, c: const Color(0xFF6B21A8))),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              if (_voiceRevealHint)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('💡 Tap the glowing one!',
                      style: _cute(sz: 20, c: const Color(0xFF22C55E))),
                ),

              // 2×2 animal option grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(36, 0, 36, 72),
                  child: AnimatedBuilder(
                    animation: _shakeController,
                    builder: (_, child) {
                      final shake = _shakeController.isAnimating
                          ? sin(_shakeController.value * 3 * pi) * 9.0
                          : 0.0;
                      return Transform.translate(
                          offset: Offset(shake, 0), child: child);
                    },
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(child: _buildVoiceOption(0)),
                              const SizedBox(width: 14),
                              Expanded(child: _buildVoiceOption(1)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(child: _buildVoiceOption(2)),
                              const SizedBox(width: 14),
                              Expanded(child: _buildVoiceOption(3)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceOption(int i) {
    final opt = _animalChoices[i];
    final isCorrect = i == _voiceCorrectIdx;

    Color bg, borderColor, labelColor;
    double borderWidth = 2.5;
    List<BoxShadow> shadows = [];

    if (_voiceAnswered && isCorrect) {
      bg = const Color(0xFFDCFCE7);
      borderColor = const Color(0xFF22C55E);
      borderWidth = 4.5;
      labelColor = const Color(0xFF166534);
      shadows = [
        BoxShadow(
            color: const Color(0xFF22C55E).withValues(alpha: 0.45),
            blurRadius: 22,
            spreadRadius: 3),
      ];
    } else if (_voiceAnswered) {
      bg = Colors.white.withValues(alpha: 0.35);
      borderColor = Colors.grey.shade200;
      labelColor = Colors.grey.shade400;
    } else if (_voiceRevealHint && isCorrect) {
      bg = const Color(0xFFDCFCE7);
      borderColor = const Color(0xFF22C55E);
      borderWidth = 4.5;
      labelColor = const Color(0xFF166534);
      shadows = [
        BoxShadow(
            color: const Color(0xFF22C55E).withValues(alpha: 0.45),
            blurRadius: 22,
            spreadRadius: 3),
      ];
    } else if (_voiceRevealHint) {
      bg = Colors.white.withValues(alpha: 0.3);
      borderColor = Colors.grey.shade200;
      labelColor = Colors.grey.shade400;
    } else if (_voiceFlashRed[i]) {
      bg = const Color(0xFFFEE2E2);
      borderColor = const Color(0xFFEF4444);
      borderWidth = 3.5;
      labelColor = const Color(0xFF991B1B);
      shadows = [
        BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.35),
            blurRadius: 16,
            spreadRadius: 2),
      ];
    } else {
      bg = Colors.white;
      borderColor = const Color(0xFFBB6BD9);
      labelColor = const Color(0xFF4C1D95);
      if (_voiceTappedIdx == i) {
        bg = const Color(0xFFEDE9FE);
        borderColor = const Color(0xFF6B21A8);
        borderWidth = 3.5;
        shadows = [
          BoxShadow(
              color: const Color(0xFF6B21A8).withValues(alpha: 0.25),
              blurRadius: 12,
              spreadRadius: 2),
        ];
      }
    }

    Widget card = GestureDetector(
      onTap: () => _onVoiceAnimalTap(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: shadows,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(opt['emoji']!,
                style: const TextStyle(
                  fontSize: 72,
                  fontFamilyFallback: [
                    'Segoe UI Emoji',
                    'Apple Color Emoji',
                    'Noto Color Emoji'
                  ],
                )),
            const SizedBox(height: 6),
            Text(
              opt['name']!,
              style: _cute(sz: 28, fw: FontWeight.w800, c: labelColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    // Pulse on correct
    if (_voiceAnswered && isCorrect) {
      card = ScaleTransition(scale: _voiceCorrectPulseAnim, child: card);
    }

    // Looping hint glow
    if (_voiceRevealHint && isCorrect) {
      card = AnimatedBuilder(
        animation: _hintController,
        builder: (_, ch) =>
            Transform.scale(scale: 1.0 + _hintController.value * 0.07, child: ch),
        child: card,
      );
    }

    return card;
  }
}
