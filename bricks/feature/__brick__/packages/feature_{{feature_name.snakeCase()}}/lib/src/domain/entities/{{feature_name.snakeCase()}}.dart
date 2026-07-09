import 'package:freezed_annotation/freezed_annotation.dart';

part '{{feature_name.snakeCase()}}.freezed.dart';

/// Pure Dart, no json, no Flutter import (§4's dependency rule) — a single
/// factory constructor, so per ADR-005 this is `abstract class`, not
/// `sealed class`.
@freezed
abstract class {{feature_name.pascalCase()}} with _${{feature_name.pascalCase()}} {
  const factory {{feature_name.pascalCase()}}({
    // TODO: replace `id` with this feature's real fields.
    required String id,
  }) = _{{feature_name.pascalCase()}};
}
