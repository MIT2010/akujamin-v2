import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/about.dart';

part 'about_model.freezed.dart';
part 'about_model.g.dart';

/// DTO that maps to the [About] domain entity (§19).
/// `@JsonKey(name: 'jenis')` replaces the old app's hand-written
/// `AboutModel.fromJson` field rename (`json['jenis']` → `type`) — same
/// transform, generated instead of hand-rolled
/// (docs/MIGRATION_PLAYBOOK.md §2a).
@freezed
abstract class AboutModel with _$AboutModel {
  const AboutModel._();

  const factory AboutModel({
    @JsonKey(name: 'jenis') required String type,
    required String text,
  }) = _AboutModel;

  factory AboutModel.fromJson(Map<String, dynamic> json) =>
      _$AboutModelFromJson(json);

  About toEntity() => About(type: type, text: text);
}
