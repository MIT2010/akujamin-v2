import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/{{feature_name.snakeCase()}}.dart';

part '{{feature_name.snakeCase()}}_model.freezed.dart';
part '{{feature_name.snakeCase()}}_model.g.dart';

/// DTO that maps to the {{feature_name.pascalCase()}} domain entity (§19).
/// Single factory constructor → `abstract class` per ADR-005.
@freezed
abstract class {{feature_name.pascalCase()}}Model with _${{feature_name.pascalCase()}}Model {
  const {{feature_name.pascalCase()}}Model._();

  const factory {{feature_name.pascalCase()}}Model({
    // TODO: replace `id` with this feature's real fields.
    required String id,
  }) = _{{feature_name.pascalCase()}}Model;

  factory {{feature_name.pascalCase()}}Model.fromJson(Map<String, dynamic> json) =>
      _${{feature_name.pascalCase()}}ModelFromJson(json);

  {{feature_name.pascalCase()}} toEntity() => {{feature_name.pascalCase()}}(id: id);
}
