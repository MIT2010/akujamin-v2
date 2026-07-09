import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/{{feature_name.snakeCase()}}.dart';
import '../../domain/repositories/{{feature_name.snakeCase()}}_repository.dart';
import '../datasources/{{feature_name.snakeCase()}}_remote_datasource.dart';

/// §20 — converts the remote model into a domain entity. Pure CRUD: no
/// local cache, no offline fallback. If this feature ever needs the §11
/// offline flow, `feature_home`'s HomeRepositoryImpl is the reference —
/// add it manually, the brick never generates it (ADR-009).
@LazySingleton(as: {{feature_name.pascalCase()}}Repository)
class {{feature_name.pascalCase()}}RepositoryImpl implements {{feature_name.pascalCase()}}Repository {
  final {{feature_name.pascalCase()}}RemoteDataSource _remote;

  {{feature_name.pascalCase()}}RepositoryImpl(this._remote);

  @override
  Future<Result<Failure, {{feature_name.pascalCase()}}>> get{{feature_name.pascalCase()}}() async {
    final result = await _remote.get{{feature_name.pascalCase()}}();
    return result.fold(
      (failure) => Err(failure),
      (model) => Ok(model.toEntity()),
    );
  }
}
