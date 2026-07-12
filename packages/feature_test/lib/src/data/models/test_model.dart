import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/test_entity.dart';
import '../../domain/entities/test_type.dart';
import 'intro_model.dart';
import 'keyed_collection.dart';
import 'section_model.dart';

part 'test_model.freezed.dart';

/// `@Freezed(fromJson: false, toJson: false)` — see `QuestionModel`'s doc
/// comment, applied defensively for the same reason.
@Freezed(fromJson: false, toJson: false)
abstract class TestModel with _$TestModel {
  const TestModel._();

  const factory TestModel({
    required String name,
    required TestType type,
    required List<SectionModel> sections,
    IntroModel? intro,
    String? instructions,
  }) = _TestModel;

  /// `name`'s the `/pertanyaan/getv2` envelope's per-entry key — same
  /// `containing "Pengetahuan"` type-detection rule as the old app's
  /// `TestModel.fromJson`, not guessed.
  factory TestModel.fromJson(String name, Map<String, dynamic> json) {
    final type = name.contains('Pengetahuan')
        ? TestType.pengetahuan
        : TestType.psikologi;
    final sectionsMap = asKeyedMap(json['bab']);

    return TestModel(
      name: name,
      type: type,
      sections: sectionsMap.entries
          .map(
            (e) => SectionModel.fromJson(
              e.key,
              e.value as Map<String, dynamic>,
              type,
            ),
          )
          .toList(),
      intro: json['intro'] != null
          ? IntroModel.fromJson(json['intro'] as Map<String, dynamic>)
          : null,
      instructions: json['instruksi'] as String?,
    );
  }

  TestEntity toEntity() => TestEntity(
    name: name,
    type: type,
    sections: sections.map((s) => s.toEntity()).toList(),
    intro: intro?.toEntity(),
    instructions: instructions,
  );
}
