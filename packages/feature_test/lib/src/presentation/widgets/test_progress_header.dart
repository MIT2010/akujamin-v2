import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/test_cubit.dart';
import '../cubit/test_state.dart';

/// Section name + "Soal N dari M" + progress bar — no back-button logic of
/// its own. Unlike the old app's `TestHeader` (which called
/// `EnableScreenshotUsecase` from its own back-button `onTap`, one of
/// three scattered call sites — permanent finding #8), screenshot
/// re-enable here happens from exactly one place, `TestPage`'s own
/// `dispose()`, which fires on *every* exit path (pop, replace-on-done,
/// even a forced navigation away) — strictly more robust than matching
/// each exit trigger by hand.
class TestProgressHeader extends StatelessWidget {
  const TestProgressHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      TestCubit,
      TestState,
      ({String section, int index, int total})?
    >(
      selector: (state) {
        final step = state.currentStep;
        if (step == null) return null;

        final test = state.findTest(step.testId);
        final section = state.findSection(test, step.sectionId);

        return (
          section: section?.name ?? '',
          index: state.currentStepIndex + 1,
          total: state.steps.length,
        );
      },
      builder: (context, data) {
        if (data == null) return const SizedBox.shrink();

        final progress = data.total == 0 ? 0.0 : data.index / data.total;

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              Text(
                data.section,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text('Soal ${data.index} dari ${data.total}'),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(value: progress, minHeight: 8),
              ),
            ],
          ),
        );
      },
    );
  }
}
