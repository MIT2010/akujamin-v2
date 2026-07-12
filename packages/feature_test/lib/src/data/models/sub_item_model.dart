import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/sub_item_entity.dart';
import 'answer_model.dart';

part 'sub_item_model.freezed.dart';

/// `@Freezed(fromJson: false, toJson: false)` — see `AnswerModel`'s doc
/// comment: with a nested `List<AnswerModel>` field, this class also reads
/// as trivially JSON-round-trippable to freezed's generator, which would
/// otherwise add the same competing `fromJson`/`toJson` despite the
/// hand-written factory below (its two-parameter signature doesn't stop
/// freezed's detection — confirmed empirically, not assumed).
@Freezed(fromJson: false, toJson: false)
abstract class SubItemModel with _$SubItemModel {
  const SubItemModel._();

  const factory SubItemModel({
    required String subId,
    required String text,
    required List<AnswerModel> answers,
  }) = _SubItemModel;

  factory SubItemModel.fromJson(String text, Map<String, dynamic> json) =>
      SubItemModel(
        subId: json['sub_id'].toString(),
        text: text,
        answers: (json['jawaban'] as List? ?? const [])
            .map((e) => AnswerModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  SubItemEntity toEntity() => SubItemEntity(
    subId: subId,
    text: text,
    answers: answers.map((a) => a.toEntity()).toList(),
  );
}
