import 'package:flutter/material.dart';

import '../controllers/audio_player_controller.dart';
import 'time_indicator.dart';

class AudioQuestionPlayer extends StatefulWidget {
  const AudioQuestionPlayer({super.key, required this.url});

  final String url;

  @override
  State<AudioQuestionPlayer> createState() => _AudioQuestionPlayerState();
}

class _AudioQuestionPlayerState extends State<AudioQuestionPlayer> {
  late final AudioPlayerController _audio;

  @override
  void initState() {
    super.initState();
    _audio = AudioPlayerController();
    _audio.load(widget.url);
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _audio,
      builder: (context, _) {
        return Row(
          children: [
            IconButton(
              icon: Icon(_audio.isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: () =>
                  _audio.isPlaying ? _audio.pause() : _audio.play(),
            ),
            Expanded(
              child: Slider(
                value: _audio.duration.inMilliseconds == 0
                    ? 0
                    : _audio.position.inMilliseconds
                          .clamp(0, _audio.duration.inMilliseconds)
                          .toDouble(),
                max: _audio.duration.inMilliseconds == 0
                    ? 1
                    : _audio.duration.inMilliseconds.toDouble(),
                onChanged: (v) =>
                    _audio.seek(Duration(milliseconds: v.round())),
              ),
            ),
            const SizedBox(width: 8),
            TimeIndicator(position: _audio.position, duration: _audio.duration),
          ],
        );
      },
    );
  }
}
