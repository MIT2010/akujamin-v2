import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'time_indicator.dart';

class VideoQuestionPlayer extends StatefulWidget {
  const VideoQuestionPlayer({super.key, required this.url});

  final String url;

  @override
  State<VideoQuestionPlayer> createState() => _VideoQuestionPlayerState();
}

class _VideoQuestionPlayerState extends State<VideoQuestionPlayer> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _controller,
      builder: (context, value, _) {
        if (!value.isInitialized) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return Column(
          children: [
            AspectRatio(
              aspectRatio: value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: () => value.isPlaying
                      ? _controller.pause()
                      : _controller.play(),
                ),
                TimeIndicator(
                  position: value.position,
                  duration: value.duration,
                ),
                Expanded(
                  child: VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
