import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Wraps `just_audio` for one question's audio clip — same shape as the old
/// app's `AudioPlayerController`.
class AudioPlayerController extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  Duration bufferedPosition = Duration.zero;
  bool isPlaying = false;

  AudioPlayerController() {
    _player.positionStream.listen((d) {
      position = d;
      notifyListeners();
    });

    _player.durationStream.listen((d) {
      duration = d ?? Duration.zero;
      notifyListeners();
    });

    _player.bufferedPositionStream.listen((d) {
      bufferedPosition = d;
      notifyListeners();
    });

    _player.playerStateStream.listen((state) {
      isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        isPlaying = false;
      }
      notifyListeners();
    });
  }

  Future<void> load(String url) => _player.setUrl(url);

  Future<void> play() => _player.play();

  Future<void> pause() => _player.pause();

  Future<void> seek(Duration d) => _player.seek(d);

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
