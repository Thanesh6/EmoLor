import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// UCD015 – Central registry of activity instructions and TTS reader.
///
/// Maintains a map of activity-id → instruction text and provides
/// text-to-speech playback. The alt-flow (no instructions defined) is
/// handled by returning `null` from [getInstructions].
class InstructionsService {
  InstructionsService._();
  static final InstructionsService instance = InstructionsService._();

  final FlutterTts _tts = FlutterTts();
  bool _ttsInitialised = false;

  /// Notifies listeners of the current word's start/end character offset
  /// during TTS playback. Both reset to -1 when speech stops.
  final ValueNotifier<int> wordStart = ValueNotifier<int>(-1);
  final ValueNotifier<int> wordEnd = ValueNotifier<int>(-1);

  // ── Instruction catalogue ─────────────────────────────────────────────

  /// Returns the instruction text for [activityId], or `null` when the
  /// System Admin has not defined instructions (alt-flow: skip step).
  String? getInstructions(String activityId) => _instructionMap[activityId];

  /// `true` when the activity has instructions defined.
  bool hasInstructions(String activityId) =>
      _instructionMap.containsKey(activityId);

  static const Map<String, String> _instructionMap = {
    // ── Games ──────────────────────────────────────────────────────────
    'game_emotion_slash': 'Emotion faces will fly across the screen!\n'
        'Draw a slash through the faces that match the target emotion.\n'
        'Be careful — slashing the wrong one loses a life!',
    'game_safe_or_not': 'Look at each picture carefully.\n'
        'Tap "Safe" if it feels okay, or "Not Safe" if it doesn\'t.',
    'game_color_memory': 'Watch the colors flash on screen.\n'
        'Then tap them in the same order!',
    'game_bubble_pop': 'Bubbles will float up with different feelings.\n'
        'Pop the bubble that matches the word shown!',
    'game_emoji_puzzle':
        'Drag each emoji piece to the matching spot on the board.\n'
            'Place all pieces correctly to complete the puzzle!',
    'game_emoji_spell': 'Look at the emoji and think of the feeling it shows.\n'
        'Tap the letters in the right order to spell the word!',
    'game_calm_garden': 'Plant seeds by tapping the soil.\n'
        'Breathe slowly — your garden grows when you\'re calm.',
    'game_emotion_signals': 'Look at the person\'s face and body.\n'
        'Pick the emotion signal they are showing!',
    'game_emotion_catcher': 'Emotion faces will fall from the sky!\n'
        'Move your basket left and right to catch the target emotion.\n'
        'Avoid catching the wrong one — you only have 3 lives!',
    'game_emo_match': 'Look at the item shown on the card.\n'
        'Tap the picture that goes with it!\n'
        'If you get it wrong twice, the right answer will glow for you.',
    'game_animal_sound':
        'In Emoji Mode, look at the animal and pick the sound it makes.\n'
            'In Voice Mode, listen to the sound and tap the correct animal.\n'
            'Tap the speaker to hear the sound again!',
    'game_emotion_sorting':
        'Look at each emoji and decide what emotion it shows.\n'
            'Drag it into the correct emotion group to sort it!\n'
            'Sort them all to earn a star!',
    // ── Drawing ────────────────────────────────────────────────────────
    'draw_free': 'Pick a colour and start drawing!\n'
        'You can change brush size with the slider.',
    'draw_calm': 'Follow the soft shapes on screen.\n'
        'Trace slowly and enjoy the colours.',

    // ── Stories ────────────────────────────────────────────────────────
    'story_happy_cloud': 'Tap "Next" to read each page of the story.\n'
        'Look at the pictures — what is the cloud feeling?',
    'story_brave_bear': 'Tap "Next" to follow the bear\'s adventure.\n'
        'Think about what being brave means!',
    'story_rainbow_friends': 'Read along about rainbow friends.\n'
        'Everyone is different — and that\'s great!',
  };

  // ── Text-to-Speech ────────────────────────────────────────────────────

  Future<void> _ensureInit() async {
    if (_ttsInitialised) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.30); // slow pace for children
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.2); // slightly higher pitch for a female feel
    await _setFemaleVoice();

    // Wire word-boundary callbacks for karaoke highlighting.
    _tts.setProgressHandler((text, start, end, word) {
      wordStart.value = start;
      wordEnd.value = end;
    });
    _tts.setCompletionHandler(() {
      wordStart.value = -1;
      wordEnd.value = -1;
    });
    _tts.setCancelHandler(() {
      wordStart.value = -1;
      wordEnd.value = -1;
    });

    _ttsInitialised = true;
  }

  /// Attempt to select a female English voice.
  ///
  /// On Chrome/Web the voice list loads asynchronously; we wait up to
  /// 1.5 s for it to populate before giving up gracefully.
  Future<void> _setFemaleVoice() async {
    try {
      // Web Speech API populates its voice list asynchronously.
      // Retry a few times with a short delay so Chrome has time to load.
      List<dynamic>? voices;
      for (int attempt = 0; attempt < 5; attempt++) {
        final v = await _tts.getVoices as List<dynamic>?;
        if (v != null && v.isNotEmpty) {
          voices = v;
          break;
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }
      if (voices == null || voices.isEmpty) return;

      // Keywords / name fragments that identify female voices across
      // platforms (Android, iOS, macOS, Windows, Chrome Web Speech API).
      const femaleKeywords = [
        'female',
        'woman',
        'girl',
        // Chrome / Edge Web Speech voices
        'google uk english female',
        'google us english',
        'microsoft zira',
        'microsoft hazel',
        'microsoft catherine',
        // macOS / iOS
        'samantha',
        'karen',
        'victoria',
        'allison',
        'ava',
        'susan',
        'moira',
        'veena',
        'fiona',
        'tessa',
        'nicky',
        'siri female',
      ];

      for (final v in voices) {
        final map = v as Map?;
        if (map == null) continue;
        final rawName = map['name'] as String? ?? '';
        final name = rawName.toLowerCase();
        final locale = (map['locale'] as String? ?? '').toLowerCase();
        // Must be an English voice
        if (!locale.startsWith('en')) continue;
        if (femaleKeywords.any((k) => name.contains(k))) {
          await _tts.setVoice(
              {'name': rawName, 'locale': map['locale'] as String? ?? 'en-US'});
          return; // done — female voice selected
        }
      }
    } catch (_) {
      // Voice selection not supported on this platform — use default.
    }
  }

  /// Speak [text] aloud. Safe to call even if TTS is unavailable on the
  /// device — errors are silently swallowed.
  Future<void> speak(String text) async {
    try {
      await _ensureInit();
      await _tts.speak(text);
    } catch (_) {
      // TTS unavailable on this device — degrade gracefully.
    }
  }

  /// Stop any ongoing speech.
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // ignore
    }
  }
}
