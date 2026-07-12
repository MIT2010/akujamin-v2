import 'package:core/core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/question_step.dart';
import '../../domain/entities/section_entity.dart';
import '../../domain/entities/test_entity.dart';

part 'test_state.freezed.dart';

enum TestStatus { loading, doing, sending, done, error, failed }

/// One flat class with a status enum, not a freezed sealed union — matches
/// `PaymentState`'s reasoning, not `ProctoringState`'s: `tests`/`steps`/
/// `currentStepIndex`/`answers` all need to keep being read while
/// `status == error` (a validation/save failure shows underneath a
/// snackbar, it doesn't blank the current question), which a sealed
/// union's disjoint variants don't fit.
@freezed
abstract class TestState with _$TestState {
  const factory TestState({
    @Default(TestStatus.loading) TestStatus status,
    @Default(<TestEntity>[]) List<TestEntity> tests,
    @Default(0) int currentStepIndex,
    @Default(<QuestionStep>[]) List<QuestionStep> steps,
    @Default(<String, List<String>>{}) Map<String, List<String>> answers,
    @Default(false) bool showIntro,
    @Default(false) bool showInstruction,
    @Default(false) bool showPopup,
    @Default(false) bool isLast,
    @Default(false) bool isSubmitting,
    int? pendingStepIndex,
    Failure? error,
  }) = _TestState;

  const TestState._();

  QuestionStep? get currentStep =>
      currentStepIndex < steps.length ? steps[currentStepIndex] : null;

  TestEntity? findTest(String testId) =>
      tests.where((t) => t.name == testId).firstOrNull;

  SectionEntity? findSection(TestEntity? test, String sectionId) =>
      test?.sections.where((s) => s.name == sectionId).firstOrNull;
}
