import 'package:core/core.dart';

import '../entities/{{feature_name.snakeCase()}}.dart';

/// Abstract contract (§18) — the domain layer defines *what* the app does,
/// never *how*. Implemented by {{feature_name.pascalCase()}}RepositoryImpl
/// in the data layer.
abstract class {{feature_name.pascalCase()}}Repository {
  Future<Result<Failure, {{feature_name.pascalCase()}}>> get{{feature_name.pascalCase()}}();
}
