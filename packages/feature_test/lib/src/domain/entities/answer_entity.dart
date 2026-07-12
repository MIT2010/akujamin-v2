import 'package:freezed_annotation/freezed_annotation.dart';

part 'answer_entity.freezed.dart';

@freezed
abstract class AnswerEntity with _$AnswerEntity {
  const factory AnswerEntity({
    required String answerId,
    required String answer,
  }) = _AnswerEntity;
}
