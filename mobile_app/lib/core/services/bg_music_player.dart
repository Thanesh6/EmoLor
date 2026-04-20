import 'package:audioplayers/audioplayers.dart';

/// Plays a single looping soft background music track from assets.
///
/// Usage (in your screen's State):
///   @override
///   void initState() {
///     super.initState();
///     BgMusicPlayer.instance.play();
///   }
///
///   @override
///   void dispose() {
///     BgMusicPlayer.instance.stop();
///     super.dispose();
///   }
class BgMusicPlayer {
  BgMusicPlayer._();
  static final BgMusicPlayer instance = BgMusicPlayer._();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  /// File name of the music track inside assets/audio/
  static const String _trackName = 'bg_music.mp3';

  /// Start playing the background music on loop.
  /// Safe to call multiple times — will not restart if already playing.
  Future<void> play() async {
    if (_isPlaying) return;
    try {
      await _player.setVolume(0.4); // 40% volume — soft/ambient level
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('audio/$_trackName'));
      _isPlaying = true;
    } catch (e) {
      // If the file is not yet added, fail silently
    }
  }

  /// Stop the background music.
  Future<void> stop() async {
    _isPlaying = false;
    await _player.stop();
  }

  /// Pause without resetting position.
  Future<void> pause() async {
    _isPlaying = false;
    await _player.pause();
  }

  /// Resume after pause.
  Future<void> resume() async {
    if (_isPlaying) return;
    _isPlaying = true;
    await _player.resume();
  }

  /// Set volume (0.0 to 1.0). Default is 0.4.
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }
}
