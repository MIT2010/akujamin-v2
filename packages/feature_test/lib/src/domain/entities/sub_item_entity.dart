import 'package:freezed_annotation/freezed_annotation.dart';

import 'answer_entity.dart';

part 'sub_item_entity.freezed.dart';

/// One sub-question within a [QuestionEntity] that has `subItems` — the old
/// app's `sub_items`, each independently answered and saved (its own
/// `QuestionStep`, sharing the parent question's `id` but carrying its own
/// `subId`).
@freezed
abstract class SubItemEntity with _$SubItemEntity {
  const factory SubItemEntity({
    required String subId,
    required String text,
    required List<AnswerEntity> answers,
  }) = _SubItemEntity;
}
