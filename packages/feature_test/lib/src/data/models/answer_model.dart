import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/answer_entity.dart';

part 'answer_model.freezed.dart';

/// Custom `fromJson`, not `json_serializable` codegen: `answerId` must
/// tolerate the backend returning either a JSON number or string for
/// `jawaban_id` (unverified against live traffic either way — normalized
/// defensively rather than assumed, same caution as the `sub_items` guard).
///
/// `@Freezed(fromJson: false, toJson: false)`, not bare `@freezed`: every
/// field here is a plain `String`, which freezed's generator recognizes as
/// trivially JSON-round-trippable — left as the default, it silently
/// generates its **own** competing `fromJson`/`toJson` expecting a
/// `answer_model.g.dart` part that nothing produces (no `@JsonSerializable`
/// here), which fails the build. Explicitly opting out lets the
/// hand-written factory below be the only one.
@Freezed(fromJson: false, toJson: false)
abstract class AnswerModel with _$AnswerModel {
  const AnswerModel._();

  const factory AnswerModel({
    required String answerId,
    required String answer,
  }) = _AnswerModel;

  factory AnswerModel.fromJson(Map<String, dynamic> json) => AnswerModel(
    answerId: json['jawaban_id'].toString(),
    answer: json['jawaban'] as String? ?? '',
  );

  AnswerEntity toEntity() => AnswerEntity(answerId: answerId, answer: answer);
}
