import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/proctoring_cubit.dart';
import '../cubit/proctoring_state.dart';

/// Ported from the old app's `test_content.dart` `BlinkingFaceStatus` —
/// real gap, found 2026-07-16 during the akujamin-app comparison audit:
/// the old app gives an always-visible early-warning signal (a blinking
/// icon) the moment `showWarning` flips true at the 2s grace-period mark,
/// well before `ViolationOverlay` blocks the whole screen at the 10s
/// `isViolation` mark. Without this, a participant drifting out of frame
/// got zero visible feedback for the first 10 seconds — they could
/// accumulate most of a violation before anything on screen told them
/// something was wrong. Uses Material icons, not the old app's
/// `detected.svg`/`undetected.svg` — no equivalent asset exists in this
/// app's design system (see the akujamin-app comparison audit's
/// design-system findings; restoring the real icon set is a separate,
/// lower-priority item).
class ProctoringStatusIndicator extends StatefulWidget {
  const ProctoringStatusIndicator({super.key});

  @override
  State<ProctoringStatusIndicator> createState() =>
      _ProctoringStatusIndicatorState();
}

class _ProctoringStatusIndicatorState extends State<ProctoringStatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _opacity = Tween<double>(begin: 1, end: 0.2).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncAnimation(bool showWarning) {
    if (showWarning && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!showWarning && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0; // back to fully opaque (begin: 1)
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProctoringCubit, ProctoringState>(
      buildWhen: (p, c) => p != c,
      builder: (context, state) {
        final showWarning = state.isWarning;
        _syncAnimation(showWarning);

        final colors = Theme.of(context).colorScheme;
        return Center(
          child: FadeTransition(
            opacity: _opacity,
            child: Icon(
              showWarning ? Icons.visibility_off : Icons.visibility,
              color: showWarning ? colors.error : colors.primary,
              size: 32,
            ),
          ),
        );
      },
    );
  }
}
