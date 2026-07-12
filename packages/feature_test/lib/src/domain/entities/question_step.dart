import 'package:freezed_annotation/freezed_annotation.dart';

part 'question_step.freezed.dart';

/// One entry in the linear, flattened list `TestCubit` walks through — one
/// per question, or one per sub-item when a question has `subItems`. Mirrors
/// the old app's `QuestionStep` exactly, including [key]'s composition (used
/// to store/look up the selected answer(s) for this exact step).
@freezed
abstract class QuestionStep with _$QuestionStep {
  const QuestionStep._();

  const factory QuestionStep({
    required String testId,
    required String sectionId,
    required String questionId,
    String? subId,
    @Default(false) bool hasTestIntro,
    @Default(false) bool hasSectionIntro,
    @Default(false) bool hasTestInstruction,
    @Default(false) bool hasSectionInstruction,
  }) = _QuestionStep;

  String get key => subId == null
      ? '${testId}_${sectionId}_$questionId'
      : '${testId}_${sectionId}_${questionId}_$subId';
}
