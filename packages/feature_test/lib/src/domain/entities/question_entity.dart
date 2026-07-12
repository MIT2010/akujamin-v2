import 'package:freezed_annotation/freezed_annotation.dart';

import 'answer_entity.dart';
import 'sub_item_entity.dart';
import 'test_type.dart';

part 'question_entity.freezed.dart';

/// `id` stays nullable, matching the old app's own `QuestionEntity` —
/// verified real API responses always populate `qid`/`id`, but nothing
/// guarantees it, and the old app crashed hard (`question.id!`) on the
/// unverified case rather than handling it. The migrated flattening step
/// (`TestCubit._buildSteps`) skips a question with no `id` instead of
/// crashing the whole test — see its doc comment.
@freezed
abstract class QuestionEntity with _$QuestionEntity {
  const factory QuestionEntity({
    required String text,
    required TestType testType,
    required bool showQuestion,
    String? id,
    String? intro,
    String? mediaType,
    String? mediaUrl,
    @Default(false) bool isMultiple,
    List<AnswerEntity>? answers,
    List<SubItemEntity>? subItems,
  }) = _QuestionEntity;
}
