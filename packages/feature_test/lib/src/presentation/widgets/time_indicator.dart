import 'package:flutter/material.dart';

/// Playback position/duration for a question's audio or video clip — **not**
/// an overall exam time limit. Confirmed by grepping the old app in full:
/// no test-wide timer/countdown exists anywhere in `test` (MIGRATION_LOG.md's
/// Langkah 3 flow map).
class TimeIndicator extends StatelessWidget {
  const TimeIndicator({
    super.key,
    required this.position,
    required this.duration,
  });

  final Duration position;
  final Duration duration;

  static String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Text('${_format(position)} / ${_format(duration)}');
  }
}
