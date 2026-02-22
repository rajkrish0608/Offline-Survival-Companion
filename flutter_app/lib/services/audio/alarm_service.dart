import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';

/// Manages the emergency alarm siren.
/// Call [start] to begin looping the siren and [stop] to silence it.
class AlarmService {
  final AudioPlayer _player = AudioPlayer();
  final Logger _logger = Logger();

  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  /// Start looping the emergency siren at full volume.
  Future<void> start() async {
    if (_isPlaying) return;
    try {
      await _player.setAsset('assets/audio/siren.wav');
      await _player.setVolume(1.0);
      await _player.setLoopMode(LoopMode.one);
      await _player.play();
      _isPlaying = true;
      _logger.i('Alarm started');
    } catch (e) {
      _logger.e('Failed to start alarm: $e');
    }
  }

  /// Stop and reset the alarm.
  Future<void> stop() async {
    if (!_isPlaying) return;
    try {
      await _player.stop();
      _isPlaying = false;
      _logger.i('Alarm stopped');
    } catch (e) {
      _logger.e('Failed to stop alarm: $e');
    }
  }

  /// Toggle alarm on/off. Returns the new playing state.
  Future<bool> toggle() async {
    if (_isPlaying) {
      await stop();
    } else {
      await start();
    }
    return _isPlaying;
  }

  /// Release audio player resources.
  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
