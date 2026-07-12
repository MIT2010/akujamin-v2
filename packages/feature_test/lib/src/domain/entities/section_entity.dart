import 'package:freezed_annotation/freezed_annotation.dart';

import 'intro_entity.dart';
import 'question_entity.dart';

part 'section_entity.freezed.dart';

@freezed
abstract class SectionEntity with _$SectionEntity {
  const factory SectionEntity({
    required String name,
    required List<QuestionEntity> questions,
    IntroEntity? intro,
    String? instructions,
  }) = _SectionEntity;
}
