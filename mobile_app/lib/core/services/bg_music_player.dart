import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

/// Plays a single looping soft background music track from assets.
///
/// The player holds Android audio focus with [AndroidAudioFocus.gain] and
/// auto-resumes if it gets paused by a transient focus loss (e.g. an SFX
/// from a game screen). It will only stop when [stop] is explicitly called
/// (logout / profile switch).
class BgMusicPlayer {
  BgMusicPlayer._();
  static final BgMusicPlayer instance = BgMusicPlayer._();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  StreamSubscription<PlayerState>? _stateSub;

  /// File name of the music track inside assets/audio/
  static const String _trackName = 'bg_music.mp3';

  // Audio context for background music — holds full media focus so Android
  // won't stop it when SFX / TTS requests transient focus.
  static AudioContext get _bgContext => AudioContext(
    android: AudioContextAndroid(
      audioFocus: AndroidAudioFocus.gain,
      stayAwake: false,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.media,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: {
        AVAudioSessionOptions.duckOthers,
      },
    ),
  );

  /// Start playing the background music on loop.
  /// Safe to call multiple times — will not restart if already playing.
  Future<void> play() async {
    if (_isPlaying) return;
    _isPlaying = true;
    try {
      await _player.setAudioContext(_bgContext);
      await _player.setVolume(0.4);
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('audio/$_trackName'));

      // Auto-resume if Android briefly pauses us due to a transient focus loss.
      _stateSub?.cancel();
      _stateSub = _player.onPlayerStateChanged.listen((state) {
        if (_isPlaying && state == PlayerState.paused) {
          _player.resume();
        }
      });
    } catch (_) {
      // If the asset is missing, fail silently.
      _isPlaying = false;
    }
  }

  /// Fully stop — called only on logout / profile switch.
  Future<void> stop() async {
    _isPlaying = false;
    _stateSub?.cancel();
    _stateSub = null;
    await _player.stop();
  }

  /// Pause without resetting position.
  Future<void> pause() async {
    _isPlaying = false;
    _stateSub?.cancel();
    await _player.pause();
  }

  /// Resume after an explicit pause.
  Future<void> resume() async {
    if (_isPlaying) return;
    _isPlaying = true;
    await _player.resume();
    // Re-arm the state listener.
    _stateSub?.cancel();
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (_isPlaying && state == PlayerState.paused) {
        _player.resume();
      }
    });
  }

  /// Set volume (0.0 to 1.0). Default is 0.4.
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }
}
