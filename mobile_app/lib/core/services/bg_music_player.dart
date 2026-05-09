import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

class BgMusicPlayer {
  BgMusicPlayer._();
  static final BgMusicPlayer instance = BgMusicPlayer._();

  final AudioPlayer _player = AudioPlayer();

  bool _shouldBePlaying = false;
  bool _isStarting = false;
  StreamSubscription<PlayerState>? _stateSub;

  static const String _trackName = 'bg_music.mp3';

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
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
      );

  Future<void> play() async {
    if (_shouldBePlaying || _isStarting) return;

    _shouldBePlaying = true;
    _isStarting = true;

    try {
      await _player.setAudioContext(_bgContext);
      await _player.setVolume(0.4);
      await _player.setReleaseMode(ReleaseMode.loop);

      _stateSub?.cancel();
      _stateSub = _player.onPlayerStateChanged.listen((state) async {
        if (!_shouldBePlaying) return;

        if (state == PlayerState.paused || state == PlayerState.stopped) {
          try {
            await _player.resume();
          } catch (_) {
            try {
              await _player.play(AssetSource('audio/$_trackName'));
            } catch (_) {}
          }
        }
      });

      await _player.play(AssetSource('audio/$_trackName'));
    } catch (_) {
      _shouldBePlaying = false;
    } finally {
      _isStarting = false;
    }
  }

  Future<void> ensurePlaying() async {
    if (!_shouldBePlaying) return;

    try {
      final state = _player.state;

      if (state == PlayerState.playing) return;

      await _player.setAudioContext(_bgContext);
      await _player.setVolume(0.4);
      await _player.setReleaseMode(ReleaseMode.loop);

      if (state == PlayerState.paused) {
        await _player.resume();
      } else {
        await _player.play(AssetSource('audio/$_trackName'));
      }
    } catch (_) {
      try {
        await _player.play(AssetSource('audio/$_trackName'));
      } catch (_) {}
    }
  }

  Future<void> stop() async {
    _shouldBePlaying = false;
    _isStarting = false;
    await _stateSub?.cancel();
    _stateSub = null;
    await _player.stop();
  }

  Future<void> pause() async {
    _shouldBePlaying = false;
    await _stateSub?.cancel();
    _stateSub = null;
    await _player.pause();
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }
}
