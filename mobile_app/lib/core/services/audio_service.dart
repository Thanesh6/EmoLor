import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Synthesised audio service — generates WAV bytes at runtime (no asset files).
/// All audio is built once on first use and cached in memory.
///
/// Usage:
///   await AudioService.instance.startBgMusic(BgMusicType.login);
///   await AudioService.instance.playSfx(SoundEffect.correct);
///   await AudioService.instance.stopBgMusic();
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  static const int _sr = 22050; // sample rate (Hz)

  final AudioPlayer _bgPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  bool _bgRunning = false;

  // ─── WAV builder ──────────────────────────────────────────────────────────

  static Uint8List _toWav(Int16List samples) {
    final dataLen = samples.length * 2;
    final buf = ByteData(44 + dataLen);
    final u8 = buf.buffer.asUint8List(buf.offsetInBytes, buf.lengthInBytes);
    void u32(int o, int v) => buf.setUint32(o, v, Endian.little);
    void u16(int o, int v) => buf.setUint16(o, v, Endian.little);

    u8.setRange(0, 4, 'RIFF'.codeUnits);
    u32(4, 36 + dataLen);
    u8.setRange(8, 12, 'WAVE'.codeUnits);
    u8.setRange(12, 16, 'fmt '.codeUnits);
    u32(16, 16);      // fmt chunk size
    u16(20, 1);       // PCM format
    u16(22, 1);       // mono
    u32(24, _sr);     // sample rate
    u32(28, _sr * 2); // byte rate
    u16(32, 2);       // block align
    u16(34, 16);      // bits per sample
    u8.setRange(36, 40, 'data'.codeUnits);
    u32(40, dataLen);

    for (int i = 0; i < samples.length; i++) {
      buf.setInt16(44 + i * 2, samples[i], Endian.little);
    }
    return u8;
  }

  // ─── Tone generator ───────────────────────────────────────────────────────

  /// Monophonic tone with ADSR envelope and two harmonics (xylophone-like).
  static Int16List _tone(
    double freq,
    double dur, {
    double vol = 0.40,
    double attack = 0.02,
    double decay = 0.06,
    double sustain = 0.75,
    double release = 0.12,
  }) {
    final n = (dur * _sr).round().clamp(1, _sr * 20);
    final s = Int16List(n);
    final aN = (attack * _sr).round();
    final dN = (decay * _sr).round();
    final rN = release <= 0 ? 1 : (release * _sr).round();
    final susN = (n - aN - dN - rN).clamp(0, n);

    for (int i = 0; i < n; i++) {
      double env;
      if (i < aN) {
        env = aN == 0 ? 1.0 : i / aN;
      } else if (i < aN + dN) {
        env = dN == 0 ? sustain : 1.0 - (1.0 - sustain) * (i - aN) / dN;
      } else if (i < aN + dN + susN) {
        env = sustain;
      } else {
        final ri = i - aN - dN - susN;
        env = sustain * (1.0 - ri / rN);
      }
      final t = i / _sr;
      // Fundamental + 2 harmonics for warmth
      final wave = sin(2 * pi * freq * t) * 0.70 +
          sin(4 * pi * freq * t) * 0.20 +
          sin(6 * pi * freq * t) * 0.10;
      s[i] = (wave * env.clamp(0.0, 1.0) * vol * 32767)
          .round()
          .clamp(-32768, 32767);
    }
    return s;
  }

  static Int16List _silence(double dur) =>
      Int16List((_sr * dur).round().clamp(1, _sr * 10));

  static Int16List _concat(List<Int16List> parts) {
    final total = parts.fold(0, (a, b) => a + b.length);
    final out = Int16List(total);
    int off = 0;
    for (final p in parts) {
      out.setRange(off, off + p.length, p);
      off += p.length;
    }
    return out;
  }

  // ─── Sound effect builders ─────────────────────────────────────────────────

  static Uint8List _buildCorrect() => _toWav(_concat([
        _tone(523.25, 0.10, vol: 0.42),
        _tone(659.25, 0.10, vol: 0.42),
        _tone(783.99, 0.16, vol: 0.48, release: 0.14),
      ]));

  static Uint8List _buildWrong() => _toWav(_concat([
        _tone(392.00, 0.09, vol: 0.32),
        _tone(311.13, 0.14, vol: 0.28, release: 0.10),
      ]));

  static Uint8List _buildComplete() => _toWav(_concat([
        _tone(523.25, 0.09, vol: 0.44),
        _tone(659.25, 0.09, vol: 0.44),
        _tone(783.99, 0.09, vol: 0.44),
        _tone(1046.50, 0.28, vol: 0.52, attack: 0.01, release: 0.22),
      ]));

  static Uint8List _buildStar() => _toWav(_concat([
        _tone(880.00, 0.06, vol: 0.38),
        _tone(1046.50, 0.06, vol: 0.38),
        _tone(1318.51, 0.12, vol: 0.44, release: 0.09),
      ]));

  static Uint8List _buildPop() {
    // Bubble: frequency sweep 800→180 Hz with fast exponential decay
    final n = (_sr * 0.11).round();
    final s = Int16List(n);
    for (int i = 0; i < n; i++) {
      final t = i / _sr;
      final freq = 800.0 * pow(180.0 / 800.0, t / 0.11).toDouble();
      final env = pow(1.0 - i / n, 1.6).toDouble();
      s[i] = (sin(2 * pi * freq * t) * env * 0.50 * 32767)
          .round()
          .clamp(-32768, 32767);
    }
    return _toWav(s);
  }

  static Uint8List _buildSnap() => _toWav(_tone(
        392.00, 0.08,
        vol: 0.44,
        attack: 0.005,
        decay: 0.025,
        sustain: 0.25,
        release: 0.04,
      ));

  static Uint8List _buildSlash() {
    // Descending frequency sweep 550→120 Hz
    final n = (_sr * 0.14).round();
    final s = Int16List(n);
    double phase = 0;
    for (int i = 0; i < n; i++) {
      final t = i / _sr;
      final freq = 550.0 * pow(120.0 / 550.0, t / 0.14).toDouble();
      phase += 2 * pi * freq / _sr;
      final env = pow(1.0 - i / n, 0.7).toDouble();
      s[i] = (sin(phase) * env * 0.44 * 32767).round().clamp(-32768, 32767);
    }
    return _toWav(s);
  }

  static Uint8List _buildCatch() => _toWav(_tone(
        783.99, 0.09,
        vol: 0.40,
        attack: 0.008,
        decay: 0.035,
        sustain: 0.40,
        release: 0.04,
      ));

  static Uint8List _buildSpell() => _toWav(_tone(
        659.25, 0.10,
        vol: 0.38,
        attack: 0.010,
        decay: 0.040,
        sustain: 0.50,
        release: 0.05,
      ));

  static Uint8List _buildClick() => _toWav(_tone(
        1000.0, 0.055,
        vol: 0.28,
        attack: 0.004,
        decay: 0.018,
        sustain: 0.18,
        release: 0.028,
      ));

  // ─── Background music builders ─────────────────────────────────────────────

  /// Calm login theme — C major pentatonic, 60 BPM (~17 sec loop)
  static Uint8List _buildBgLogin() {
    const b = 1.0; // beat = 1 sec at 60 BPM
    final notes = <(double, double)>[
      (261.63, b * 1.5), // C4
      (329.63, b * 0.75), // E4
      (392.00, b * 0.75), // G4
      (440.00, b * 1.5), // A4
      (392.00, b * 0.75), // G4
      (329.63, b * 0.75), // E4
      (261.63, b * 2.5), // C4 long
      (0.0,    b * 0.5), // rest
      (329.63, b * 0.75), // E4
      (440.00, b * 0.75), // A4
      (523.25, b * 1.5), // C5
      (440.00, b * 0.75), // A4
      (392.00, b * 0.75), // G4
      (329.63, b * 0.75), // E4
      (261.63, b * 3.0), // C4 whole
      (0.0,    b * 0.75), // rest
    ];
    final parts = notes.map<Int16List>((e) => e.$1 == 0
        ? _silence(e.$2)
        : _tone(e.$1, e.$2,
            vol: 0.28,
            attack: 0.06,
            decay: 0.10,
            sustain: 0.65,
            release: 0.22)).toList();
    return _toWav(_concat(parts));
  }

  /// Upbeat dashboard theme — C major pentatonic, 105 BPM (~9 sec loop)
  static Uint8List _buildBgDashboard() {
    const bpm = 105.0;
    final b = 60.0 / bpm;
    final notes = <(double, double)>[
      (523.25,  b * 0.5),
      (659.25,  b * 0.5),
      (783.99,  b * 0.5),
      (880.00,  b * 0.5),
      (1046.50, b * 1.0),
      (880.00,  b * 0.5),
      (783.99,  b * 0.5),
      (659.25,  b * 1.0),
      (0.0,     b * 0.5),
      (523.25,  b * 0.5),
      (659.25,  b * 0.5),
      (440.00,  b * 0.75),
      (392.00,  b * 0.25),
      (523.25,  b * 1.0),
      (0.0,     b * 0.5),
      (783.99,  b * 0.5),
      (659.25,  b * 0.5),
      (523.25,  b * 0.5),
      (659.25,  b * 0.5),
      (783.99,  b * 1.5),
      (0.0,     b * 0.5),
    ];
    final parts = notes.map<Int16List>((e) => e.$1 == 0
        ? _silence(e.$2)
        : _tone(e.$1, e.$2,
            vol: 0.26,
            attack: 0.02,
            decay: 0.05,
            sustain: 0.75,
            release: 0.09)).toList();
    return _toWav(_concat(parts));
  }

  // ─── Cache ────────────────────────────────────────────────────────────────

  final Map<SoundEffect, Uint8List> _cache = {};
  Uint8List? _bgLoginWav;
  Uint8List? _bgDashWav;

  Uint8List _get(SoundEffect e) => _cache.putIfAbsent(e, () => switch (e) {
        SoundEffect.correct  => _buildCorrect(),
        SoundEffect.wrong    => _buildWrong(),
        SoundEffect.complete => _buildComplete(),
        SoundEffect.star     => _buildStar(),
        SoundEffect.pop      => _buildPop(),
        SoundEffect.snap     => _buildSnap(),
        SoundEffect.slash    => _buildSlash(),
        SoundEffect.catchSfx => _buildCatch(),
        SoundEffect.spell    => _buildSpell(),
        SoundEffect.click    => _buildClick(),
      });

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Start looping background music. Safe to call if already running.
  Future<void> startBgMusic(BgMusicType type) async {
    if (_bgRunning) return;
    _bgRunning = true;
    await _bgPlayer.stop(); // clear any stale state
    await _bgPlayer.setReleaseMode(ReleaseMode.loop);
    final wav = type == BgMusicType.login
        ? (_bgLoginWav ??= _buildBgLogin())
        : (_bgDashWav ??= _buildBgDashboard());
    await _bgPlayer.play(BytesSource(wav));
  }

  /// Stop background music.
  Future<void> stopBgMusic() async {
    _bgRunning = false;
    await _bgPlayer.stop();
  }

  /// Play a one-shot sound effect (non-blocking).
  Future<void> playSfx(SoundEffect effect) async {
    await _sfxPlayer.play(BytesSource(_get(effect)));
  }
}

enum SoundEffect {
  correct,
  wrong,
  complete,
  star,
  pop,
  snap,
  slash,
  catchSfx,
  spell,
  click,
}

enum BgMusicType { login, dashboard }
