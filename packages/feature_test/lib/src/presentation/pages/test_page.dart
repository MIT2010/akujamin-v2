import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import '../../domain/entities/question_step.dart';
import '../cubit/proctoring_cubit.dart';
import '../cubit/test_cubit.dart';
import '../cubit/test_state.dart';
import '../widgets/question_view.dart';
import '../widgets/test_done_popup.dart';
import '../widgets/test_info_view.dart';
import '../widgets/test_progress_header.dart';
import '../widgets/violation_overlay.dart';

/// Migrated from the old app's `test` feature (write-path: linear
/// question/answer flow, POST-per-question save, camera/proctoring, real
/// screenshot protection). See MIGRATION_LOG.md's Langkah 3-4 flow map and
/// docs/qa/test.md for the full audit this was built from.
class TestPage extends StatelessWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    final voucherCode = GoRouterState.of(context).pathParameters['voucher']!;

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<TestCubit>()..getTests(voucherCode)),
        BlocProvider(create: (_) => getIt<ProctoringCubit>()..start()),
      ],
      child: const TestView(),
    );
  }
}

/// Split from [TestPage] (left un-exported from the barrel) so widget tests
/// can drive it directly with fake cubits via `BlocProvider.value` — same
/// pattern as every other feature's page.
class TestView extends StatelessWidget {
  const TestView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<TestCubit, TestState>(
      listenWhen: (p, c) => p.status != c.status || p.showPopup != c.showPopup,
      listener: _handleSideEffect,
      child: Scaffold(
        appBar: AppBar(title: const Text('Tes')),
        body: const Stack(children: [_TestBody(), ViolationOverlay()]),
      ),
    );
  }

  void _handleSideEffect(BuildContext context, TestState state) {
    switch (state.status) {
      case TestStatus.error:
        final message = state.error?.message;
        if (message != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      case TestStatus.done:
        context.pushReplacement('/result');
      case TestStatus.doing when state.showPopup:
        AppBottomSheet.show(
          context,
          builder: (_) => TestDonePopup(
            sectionName: state.currentStep?.sectionId ?? '',
            isLast: state.isLast,
          ),
        ).then((_) {
          if (context.mounted) context.read<TestCubit>().closePopup();
        });
      default:
        break;
    }
  }
}

class _TestBody extends StatelessWidget {
  const _TestBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TestCubit, TestState>(
      buildWhen: (p, c) =>
          p.status != c.status ||
          p.currentStepIndex != c.currentStepIndex ||
          p.showIntro != c.showIntro ||
          p.showInstruction != c.showInstruction,
      builder: (context, state) {
        if (state.status == TestStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        final step = state.currentStep;
        if (step == null) {
          return _TestErrorFallback(message: state.error?.message);
        }

        return Column(
          children: [
            const TestProgressHeader(),
            Expanded(
              child: state.showIntro
                  ? _buildIntro(context, state, step)
                  : state.showInstruction
                  ? _buildInstruction(context, state, step)
                  : const QuestionView(),
            ),
          ],
        );
      },
    );
  }

  /// Both title and content are sourced from the **same** level (section
  /// first, falling back to test) — a small, deliberate fix over the old
  /// app's `IntroView`, whose title preferred the section name but its
  /// content preferred the test's description, so the two could genuinely
  /// mismatch (a section-titled popup showing the parent test's text) any
  /// time both a test-level and section-level intro existed at the same
  /// boundary. MIGRATION_LOG.md's Langkah 3 flow map.
  Widget _buildIntro(BuildContext context, TestState state, QuestionStep step) {
    final test = state.findTest(step.testId);
    final section = state.findSection(test, step.sectionId);
    final name = section?.name ?? test?.name ?? '';
    final intro = section?.intro ?? test?.intro;

    return TestInfoView(
      title: 'Pengenalan $name',
      content: intro?.description ?? '',
      imageUrl: intro?.imageUrl,
      onNext: () => context.read<TestCubit>().dismissIntro(),
    );
  }

  Widget _buildInstruction(
    BuildContext context,
    TestState state,
    QuestionStep step,
  ) {
    final test = state.findTest(step.testId);
    final section = state.findSection(test, step.sectionId);
    final name = section?.name ?? test?.name ?? '';
    final instructions = section?.instructions ?? test?.instructions ?? '';

    return TestInfoView(
      title: 'Instruksi $name',
      content: instructions,
      onNext: () => context.read<TestCubit>().dismissInstruction(),
    );
  }
}

class _TestErrorFallback extends StatelessWidget {
  const _TestErrorFallback({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Oops!', style: TextStyle(fontSize: 20)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message ?? 'Terjadi kesalahan. Silakan coba lagi.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(label: 'Kembali', onPressed: () => context.pop()),
          ],
        ),
      ),
    );
  }
}
