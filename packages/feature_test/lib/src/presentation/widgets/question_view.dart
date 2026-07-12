import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/test_cubit.dart';
import '../cubit/test_state.dart';
import 'answer_option.dart';
import 'audio_question_player.dart';
import 'video_question_player.dart';

class QuestionView extends StatelessWidget {
  const QuestionView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TestCubit, TestState>(
      buildWhen: (p, c) =>
          p.currentStep != c.currentStep ||
          p.answers != c.answers ||
          p.isSubmitting != c.isSubmitting,
      builder: (context, state) {
        final step = state.currentStep;
        if (step == null) return const SizedBox.shrink();

        final test = state.findTest(step.testId);
        final section = state.findSection(test, step.sectionId);
        final question = section?.questions
            .where((q) => q.id == step.questionId)
            .firstOrNull;

        if (question == null) return const SizedBox.shrink();

        final subItem = step.subId == null
            ? null
            : question.subItems
                  ?.where((s) => s.subId == step.subId)
                  .firstOrNull;

        final answers = step.subId == null
            ? (question.answers ?? const [])
            : (subItem?.answers ?? const []);
        final selectedIds = state.answers[step.key] ?? const [];
        final cubit = context.read<TestCubit>();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (question.intro != null) ...[
                Text(
                  question.intro!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (question.mediaType == 'image' && question.mediaUrl != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Image.network(question.mediaUrl!),
                ),
              if (question.mediaType == 'audio' && question.mediaUrl != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AudioQuestionPlayer(url: question.mediaUrl!),
                ),
              if (question.mediaType == 'video' && question.mediaUrl != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: VideoQuestionPlayer(url: question.mediaUrl!),
                ),
              // Real, low-risk fix over the old app: `subItem.text` is a
              // real field fetched from every sub-item response but the
              // old app's `QuestionView` never rendered it anywhere — every
              // sub-question step showed the same parent question text with
              // only the answer options changing, no indication of what was
              // actually being asked per step. Falls back to the parent
              // question's text when there's no sub-item, so a plain
              // question renders identically to before.
              if (question.showQuestion)
                Text(
                  subItem?.text ?? question.text,
                  style: const TextStyle(fontSize: 16),
                ),
              const SizedBox(height: AppSpacing.md),
              for (final answer in answers)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AnswerOption(
                    text: answer.answer,
                    isSelected: question.isMultiple
                        ? selectedIds.contains(answer.answerId)
                        : selectedIds.firstOrNull == answer.answerId,
                    onTap: state.isSubmitting
                        ? null
                        : () => cubit.selectAnswer(
                            testId: step.testId,
                            sectionId: step.sectionId,
                            questionId: step.questionId,
                            subId: step.subId,
                            answerId: answer.answerId,
                            isMultiple: question.isMultiple,
                          ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  label: 'Lanjut',
                  loading: state.isSubmitting,
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () => cubit.nextStep(step),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
