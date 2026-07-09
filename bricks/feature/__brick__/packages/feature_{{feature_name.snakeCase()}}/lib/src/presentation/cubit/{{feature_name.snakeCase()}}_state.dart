import 'package:core/core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/{{feature_name.snakeCase()}}.dart';

part '{{feature_name.snakeCase()}}_state.freezed.dart';

/// freezed 3.x requires `sealed class` for union types with multiple
/// factory constructors (ADR-005).
@freezed
sealed class {{feature_name.pascalCase()}}State with _${{feature_name.pascalCase()}}State {
  const factory {{feature_name.pascalCase()}}State.initial() = {{feature_name.pascalCase()}}Initial;
  const factory {{feature_name.pascalCase()}}State.loading() = {{feature_name.pascalCase()}}Loading;
  const factory {{feature_name.pascalCase()}}State.loaded({{feature_name.pascalCase()}} {{feature_name.camelCase()}}) = {{feature_name.pascalCase()}}Loaded;
  const factory {{feature_name.pascalCase()}}State.error(Failure failure) = {{feature_name.pascalCase()}}Error;
}
