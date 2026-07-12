import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/question_step.dart';
import '../../domain/entities/test_entity.dart';
import '../../domain/repositories/screenshot_gateway.dart';
import '../../domain/repositories/test_repository.dart';
import 'test_state.dart';

/// No UseCase (§21/ADR-004) — see `TestRepository`'s doc comment. Mirrors
/// the old app's `TestStateCubit`: linear-step flattening, immediate
/// per-question save, non-dismissible section/test-boundary popup staged
/// via `pendingStepIndex`.
///
/// **Real fix for permanent finding #8, not a port**: the old app's
/// screenshot disable call was commented out in `TestPage.initState()`, so
/// protection never actually engaged during a live exam, while its enable
/// call was scattered across three separate UI triggers (back button,
/// done-state handler, double-back-exit wrapper) that all had to be kept in
/// sync by hand. Screenshot lifecycle lives here instead, in the
/// constructor and [close] — same "side effect tied to the cubit's own
/// lifecycle" shape `PaymentCubit` already uses for its socket connection
/// (`disconnectSocket()` from `close()`) — so there is exactly **one**
/// enable call site, and it fires on every possible exit path (`Cubit`'s
/// `close()` always runs when its `BlocProvider` is disposed), not just the
/// ones someone remembered to wire up.
@injectable
class TestCubit extends Cubit<TestState> {
  TestCubit(this._repository, this._screenshotGateway)
    : super(const TestState()) {
    _screenshotGateway.disable();
  }

  final TestRepository _repository;
  final ScreenshotGateway _screenshotGateway;
  late String _voucherCode;

  Future<void> getTests(String voucherCode) async {
    emit(state.copyWith(status: TestStatus.loading));
    _voucherCode = voucherCode;

    final result = await _repository.getTests(voucherCode);

    result.fold(
      (failure) =>
          emit(state.copyWith(status: TestStatus.failed, error: failure)),
      (tests) {
        final steps = _buildSteps(tests);

        if (steps.isEmpty) {
          emit(
            state.copyWith(
              status: TestStatus.failed,
              error: const ServerFailure(
                'Tes tidak tersedia saat ini. Silakan coba lagi.',
              ),
            ),
          );
          return;
        }

        emit(
          state.copyWith(
            status: TestStatus.doing,
            tests: tests,
            steps: steps,
            showIntro: steps.first.hasTestIntro || steps.first.hasSectionIntro,
            showInstruction:
                steps.first.hasTestInstruction ||
                steps.first.hasSectionInstruction,
          ),
        );
      },
    );
  }

  void selectAnswer({
    required String testId,
    required String sectionId,
    required String questionId,
    String? subId,
    required String answerId,
    required bool isMultiple,
  }) {
    final stepKey = QuestionStep(
      testId: testId,
      sectionId: sectionId,
      questionId: questionId,
      subId: subId,
    ).key;

    final current = state.answers[stepKey] ?? const [];
    final updated = isMultiple
        ? (current.contains(answerId)
              ? current.where((id) => id != answerId).toList()
              : [...current, answerId])
        : [answerId];

    emit(state.copyWith(answers: {...state.answers, stepKey: updated}));
  }

  Future<void> nextStep(QuestionStep step) async {
    emit(state.copyWith(status: TestStatus.sending, isSubmitting: true));

    if (!await _saveAnswer(step)) return;

    final currentIndex = state.currentStepIndex;
    final isLastStep = currentIndex == state.steps.length - 1;
    final currentStep = state.steps[currentIndex];
    final nextIndex = isLastStep ? currentIndex : currentIndex + 1;
    final nextQuestionStep = isLastStep ? null : state.steps[nextIndex];

    final testChanged =
        nextQuestionStep != null &&
        nextQuestionStep.testId != currentStep.testId;
    final sectionChanged =
        nextQuestionStep != null &&
        nextQuestionStep.sectionId != currentStep.sectionId;

    if (testChanged || sectionChanged) {
      emit(
        state.copyWith(
          status: TestStatus.doing,
          showPopup: true,
          isLast: false,
          pendingStepIndex: nextIndex,
          isSubmitting: false,
        ),
      );
      return;
    }

    if (isLastStep) {
      emit(
        state.copyWith(
          status: TestStatus.doing,
          showPopup: true,
          isLast: true,
          isSubmitting: false,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: TestStatus.doing,
        currentStepIndex: nextIndex,
        isSubmitting: false,
      ),
    );
  }

  void closePopup() {
    if (state.isLast) {
      emit(state.copyWith(status: TestStatus.done));
      return;
    }

    final nextIndex = state.pendingStepIndex;
    if (nextIndex == null) return;

    final next = state.steps[nextIndex];

    emit(
      state.copyWith(
        currentStepIndex: nextIndex,
        showPopup: false,
        pendingStepIndex: null,
        showIntro: next.hasTestIntro || next.hasSectionIntro,
        showInstruction: next.hasTestInstruction || next.hasSectionInstruction,
        isLast: nextIndex == state.steps.length - 1,
      ),
    );
  }

  void dismissIntro() => emit(state.copyWith(showIntro: false));

  void dismissInstruction() => emit(state.copyWith(showInstruction: false));

  /// **Second, independent validation layer (approved design decision,
  /// 2026-07-12).** `_NextButton` already gates on the UI side
  /// (`selectedIds.isNotEmpty`), but this is psychological-test-result
  /// data POSTed per question — immediately, not batch-reviewed — so the
  /// cubit itself must also refuse an empty submission rather than trust
  /// the UI never allows one to happen. Returns `false`, and never calls
  /// the repository at all, when the current step has no selected answer.
  Future<bool> _saveAnswer(QuestionStep step) async {
    final answerIds = state.answers[step.key] ?? const [];

    if (answerIds.isEmpty) {
      emit(
        state.copyWith(
          status: TestStatus.error,
          isSubmitting: false,
          error: const ValidationFailure('Jawaban tidak boleh kosong.'),
        ),
      );
      return false;
    }

    final test = state.findTest(step.testId);
    final section = state.findSection(test, step.sectionId);
    final question = section?.questions
        .where((q) => q.id == step.questionId)
        .firstOrNull;

    if (question == null) {
      emit(
        state.copyWith(
          status: TestStatus.error,
          isSubmitting: false,
          error: const ValidationFailure('Soal tidak ditemukan.'),
        ),
      );
      return false;
    }

    final result = await _repository.saveTestAnswer(
      question: question,
      answerIds: answerIds,
      voucherCode: _voucherCode,
      subId: step.subId,
    );

    return result.fold((failure) {
      emit(
        state.copyWith(
          status: TestStatus.error,
          error: failure,
          isSubmitting: false,
        ),
      );
      return false;
    }, (_) => true);
  }

  /// Flattens `TestEntity -> SectionEntity -> QuestionEntity(+SubItem)`
  /// into one linear list, one step per question or per sub-item — same
  /// shape as the old app's `TestStateCubit._buildStepsForTests`.
  ///
  /// **Defensive addition, not in the old app**: a question with no `id`
  /// (nullable in the entity — see its doc comment) is skipped instead of
  /// crashing the whole test on a null-check. There's no way to key its
  /// answer or its save request without an id, so including it anyway
  /// would only move the crash from here to `_saveAnswer`.
  List<QuestionStep> _buildSteps(List<TestEntity> tests) {
    final steps = <QuestionStep>[];

    for (final test in tests) {
      for (final section in test.sections) {
        for (final question in section.questions) {
          final questionId = question.id;
          if (questionId == null) continue;

          final subItems = question.subItems;

          if (subItems == null || subItems.isEmpty) {
            steps.add(
              QuestionStep(
                testId: test.name,
                sectionId: section.name,
                questionId: questionId,
                hasTestIntro: test.intro != null,
                hasSectionIntro: section.intro != null,
                hasTestInstruction: test.instructions != null,
                hasSectionInstruction: section.instructions != null,
              ),
            );
          } else {
            for (final sub in subItems) {
              steps.add(
                QuestionStep(
                  testId: test.name,
                  sectionId: section.name,
                  questionId: questionId,
                  subId: sub.subId,
                  hasTestIntro: test.intro != null,
                  hasSectionIntro: section.intro != null,
                  hasTestInstruction: test.instructions != null,
                  hasSectionInstruction: section.instructions != null,
                ),
              );
            }
          }
        }
      }
    }

    return steps;
  }

  @override
  Future<void> close() async {
    await _screenshotGateway.enable();
    return super.close();
  }
}
