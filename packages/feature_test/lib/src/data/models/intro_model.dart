import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/intro_entity.dart';

part 'intro_model.freezed.dart';

/// `@Freezed(fromJson: false, toJson: false)` — see `AnswerModel`'s doc
/// comment: bare `@freezed` here would silently generate a competing
/// `fromJson`/`toJson` expecting a nonexistent `intro_model.g.dart`.
@Freezed(fromJson: false, toJson: false)
abstract class IntroModel with _$IntroModel {
  const IntroModel._();

  const factory IntroModel({String? description, String? imageUrl}) =
      _IntroModel;

  factory IntroModel.fromJson(Map<String, dynamic> json) => IntroModel(
    description: json['deskripsi'] as String?,
    imageUrl: json['image'] as String?,
  );

  IntroEntity toEntity() =>
      IntroEntity(description: description, imageUrl: imageUrl);
}
