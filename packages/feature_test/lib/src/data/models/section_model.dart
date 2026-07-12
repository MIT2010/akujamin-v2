import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/section_entity.dart';
import '../../domain/entities/test_type.dart';
import 'intro_model.dart';
import 'keyed_collection.dart';
import 'question_model.dart';

part 'section_model.freezed.dart';

/// `@Freezed(fromJson: false, toJson: false)` — see `QuestionModel`'s doc
/// comment, applied defensively for the same reason.
@Freezed(fromJson: false, toJson: false)
abstract class SectionModel with _$SectionModel {
  const SectionModel._();

  const factory SectionModel({
    required String name,
    required List<QuestionModel> questions,
    IntroModel? intro,
    String? instructions,
  }) = _SectionModel;

  factory SectionModel.fromJson(
    String name,
    Map<String, dynamic> json,
    TestType type,
  ) {
    final questionsMap = asKeyedMap(json['soal']);

    return SectionModel(
      name: name,
      questions: questionsMap.entries
          .map(
            (e) => QuestionModel.fromJson(
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

  SectionEntity toEntity() => SectionEntity(
    name: name,
    questions: questions.map((q) => q.toEntity()).toList(),
    intro: intro?.toEntity(),
    instructions: instructions,
  );
}
