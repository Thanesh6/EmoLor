import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Generates and plays simple programmatic tones for goal alerts.
/// No external audio files needed — WAV PCM bytes are synthesised in Dart.
///
/// IMPORTANT — audio focus:
/// These tones are notification-style SFX that must coexist with the
/// looping background music ([BgMusicPlayer]).  Without an explicit
/// AudioContext the player defaults to `AndroidAudioFocus.gain`, which
/// steals full focus and **stops** the bg music every time a goal alert
/// fires.  We override that with `gainTransientMayDuck` (Android) /
/// `ambient` (iOS) so the music briefly ducks but is never interrupted.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final AudioPlayer _player = AudioPlayer();
  bool _audioContextSet = false;

  /// Audio context for goal-alert beeps.
  ///
  /// • Android: `gainTransientMayDuck` — Android automatically lowers the
  ///   bg music volume for the duration of the beep and restores it after.
  ///   Music is **never** paused or stopped.
  /// • iOS: `ambient` with `mixWithOthers` — beep plays mixed on top of
  ///   the music; neither stream interrupts the other.
  static AudioContext get _sfxContext => AudioContext(
        android: AudioContextAndroid(
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: {
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
      );

  Future<void> _ensureAudioContext() async {
    if (_audioContextSet) return;
    _audioContextSet = true;
    try {
      await _player.setAudioContext(_sfxContext);
    } catch (_) {
      // If the platform rejects the context, fall back to default — at
      // worst the music ducks/stops as before; we never throw.
    }
  }

  // ── Public API ────────────────────────────────────────────────────

  /// Play a warning beep based on minutes remaining.
  /// 10 min → 1 low beep, 5 min → 2 medium beeps, 1 min → 3 rapid high beeps.
  Future<void> playTimeWarning(int minutesLeft) async {
    if (minutesLeft <= 1) {
      await _playSequence([880.0, 880.0, 880.0], 0.18);
    } else if (minutesLeft <= 5) {
      await _playSequence([660.0, 660.0], 0.22);
    } else {
      await _playTone(440.0, 0.30);
    }
    HapticFeedback.mediumImpact();
  }

  /// Three descending tones — the "time is over" signal.
  Future<void> playTimeUp() async {
    await _playSequence([523.0, 392.0, 261.0], 0.40);
    HapticFeedback.heavyImpact();
  }

  /// Celebratory chime scaled to milestone level.
  /// fraction: 0.5 → single chime, 0.8 → two rising notes, 1.0 → full arpeggio.
  Future<void> playStarMilestone(double fraction) async {
    if (fraction >= 1.0) {
      // Victory arpeggio — four ascending notes
      await _playSequence([523.0, 659.0, 784.0, 1047.0], 0.22);
      HapticFeedback.heavyImpact();
    } else if (fraction >= 0.8) {
      await _playSequence([523.0, 784.0], 0.28);
      HapticFeedback.mediumImpact();
    } else {
      // 50%
      await _playTone(659.0, 0.35);
      HapticFeedback.lightImpact();
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }

  // ── Private helpers ───────────────────────────────────────────────

  Future<void> _playTone(double freq, double durSec) async {
    try {
      // Configure audio focus on first use so goal-alert beeps coexist
      // with the looping bg music instead of stopping it.
      await _ensureAudioContext();
      final bytes = _generateWav(freq, durSec);
      await _player.play(BytesSource(bytes));
    } catch (_) {
      // Silently ignore if audio fails (simulator, muted, etc.)
    }
  }

  Future<void> _playSequence(List<double> freqs, double durPerNote) async {
    for (final freq in freqs) {
      await _playTone(freq, durPerNote);
      // Brief gap between notes
      await Future.delayed(
          Duration(milliseconds: (durPerNote * 1000 + 40).toInt()));
    }
  }

  /// Synthesise a raw PCM WAV for a pure sine tone.
  Uint8List _generateWav(double frequency, double durationSec) {
    const sampleRate = 22050;
    const amplitude = 9000; // ~55% of 16-bit max — comfortable volume
    final numSamples = (sampleRate * durationSec).toInt();

    final pcm = Uint8List(numSamples * 2);
    final view = ByteData.sublistView(pcm);

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      // Short fade-in + fade-out to prevent click artefacts
      final fadeIn =
          i < sampleRate * 0.012 ? i / (sampleRate * 0.012) : 1.0;
      final fadeOut = i > numSamples - sampleRate * 0.06
          ? (numSamples - i) / (sampleRate * 0.06)
          : 1.0;
      final env = (fadeIn * fadeOut).clamp(0.0, 1.0);
      final raw = (amplitude * env * sin(2 * pi * frequency * t)).toInt();
      view.setInt16(i * 2, raw.clamp(-32768, 32767), Endian.little);
    }

    // Build WAV file header + PCM data
    final b = BytesBuilder();
    void str(String s) => b.add(s.codeUnits);
    void u32(int v) =>
        b.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
    void u16(int v) => b.add([v & 0xFF, (v >> 8) & 0xFF]);

    final dataSize = numSamples * 2;
    str('RIFF');
    u32(36 + dataSize); // file size − 8
    str('WAVE');
    str('fmt ');
    u32(16); // PCM fmt chunk size
    u16(1); // PCM format
    u16(1); // mono
    u32(sampleRate);
    u32(sampleRate * 2); // byte rate (1 ch × 2 bytes × sampleRate)
    u16(2); // block align
    u16(16); // bits per sample
    str('data');
    u32(dataSize);
    b.add(pcm);

    return b.toBytes();
  }
}
