import 'package:freezed_annotation/freezed_annotation.dart';

import 'intro_entity.dart';
import 'section_entity.dart';
import 'test_type.dart';

part 'test_entity.freezed.dart';

@freezed
abstract class TestEntity with _$TestEntity {
  const factory TestEntity({
    required String name,
    required TestType type,
    required List<SectionEntity> sections,
    IntroEntity? intro,
    String? instructions,
  }) = _TestEntity;
}
