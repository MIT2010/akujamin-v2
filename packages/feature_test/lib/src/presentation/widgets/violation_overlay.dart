import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/attention_status.dart';
import '../cubit/proctoring_cubit.dart';
import '../cubit/proctoring_state.dart';

/// Full-screen block while proctoring reports a violation — `isViolation`
/// (10s past the grace period) or a hard camera failure. Reads
/// `ProctoringCubit` directly (already provided by `TestPage`, alongside
/// `TestCubit`) rather than threading its state through `TestState`, same
/// separation the camera/proctoring prerequisite audit settled on: the
/// proctoring state machine stays its own thing, `test`'s question/answer
/// flow doesn't know or care about it beyond "is the screen currently
/// blocked".
class ViolationOverlay extends StatelessWidget {
  const ViolationOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProctoringCubit, ProctoringState>(
      buildWhen: (p, c) => p != c,
      builder: (context, state) {
        final content = switch (state) {
          ProctoringDetecting(isViolation: true, :final status) => _contentFor(
            status,
          ),
          ProctoringCameraUnavailable(:final message) => _ViolationContent(
            icon: Icons.videocam_off_rounded,
            title: 'Kamera tidak tersedia',
            description: message,
          ),
          _ => null,
        };

        if (content == null) return const SizedBox.shrink();

        return Positioned.fill(
          child: ColoredBox(
            color: Colors.black54,
            child: Center(
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(content.icon, size: 48),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        content.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(content.description, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  _ViolationContent _contentFor(AttentionStatus status) => switch (status) {
    AttentionStatus.noFace => const _ViolationContent(
      icon: Icons.visibility_off,
      title: 'Wajah tidak terdeteksi',
      description: 'Silakan kembali menghadap layar untuk melanjutkan tes.',
    ),
    AttentionStatus.multipleFaces => const _ViolationContent(
      icon: Icons.people_alt_rounded,
      title: 'Terdeteksi lebih dari satu wajah',
      description: 'Pastikan kamu sendirian untuk melanjutkan tes.',
    ),
    AttentionStatus.attentive => const _ViolationContent(
      icon: Icons.person_off_rounded,
      title: 'Wajah tidak cocok',
      description:
          'Tes tidak dapat dilanjutkan karena wajah tidak cocok dengan data peserta.',
    ),
  };
}

class _ViolationContent {
  const _ViolationContent({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
