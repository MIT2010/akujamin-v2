import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/question_entity.dart';
import '../../domain/entities/test_type.dart';
import 'answer_model.dart';
import 'keyed_collection.dart';
import 'sub_item_model.dart';

part 'question_model.freezed.dart';

/// The map key this is parsed from (`soal`'s per-entry key) is the question
/// **text**, not an id — `id` is a separate field inside the value
/// (`qid`/`id`), exactly as the old app's `QuestionModel.fromJson` reads it.
///
/// `@Freezed(fromJson: false, toJson: false)` for the same reason as
/// `AnswerModel` — applied defensively here too, even though this class's
/// current field mix (an enum, nested non-auto-serializable models)
/// happens not to trigger freezed's auto-detection today; that's an
/// incidental side effect of the field types, not something to rely on
/// staying true.
@Freezed(fromJson: false, toJson: false)
abstract class QuestionModel with _$QuestionModel {
  const QuestionModel._();

  const factory QuestionModel({
    required String text,
    required TestType testType,
    required bool showQuestion,
    String? id,
    String? intro,
    String? mediaType,
    String? mediaUrl,
    @Default(false) bool isMultiple,
    List<AnswerModel>? answers,
    List<SubItemModel>? subItems,
  }) = _QuestionModel;

  factory QuestionModel.fromJson(
    String text,
    Map<String, dynamic> json,
    TestType type,
  ) {
    final subItemsMap = asKeyedMap(json['sub_items']);

    return QuestionModel(
      text: text,
      testType: type,
      showQuestion: json['show_question'] as bool? ?? true,
      id: (json['qid'] ?? json['id'])?.toString(),
      intro: json['intro'] as String?,
      mediaType: json['mediaType'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      isMultiple: json['is_multiple'] == 1,
      answers: (json['jawaban'] as List?)
          ?.map((e) => AnswerModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      subItems: subItemsMap.isEmpty
          ? null
          : subItemsMap.entries
                .map(
                  (e) => SubItemModel.fromJson(
                    e.key,
                    e.value as Map<String, dynamic>,
                  ),
                )
                .toList(),
    );
  }

  QuestionEntity toEntity() => QuestionEntity(
    text: text,
    testType: testType,
    showQuestion: showQuestion,
    id: id,
    intro: intro,
    mediaType: mediaType,
    mediaUrl: mediaUrl,
    isMultiple: isMultiple,
    answers: answers?.map((a) => a.toEntity()).toList(),
    subItems: subItems?.map((s) => s.toEntity()).toList(),
  );
}
