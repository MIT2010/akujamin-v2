import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

import '../models/{{feature_name.snakeCase()}}_model.dart';

/// §19 — talks to the API through `core`'s one Dio instance. Throws
/// nothing itself; [ApiClient] already converts [DioException] into a
/// typed [Failure] before this ever sees it.
@injectable
class {{feature_name.pascalCase()}}RemoteDataSource {
  final ApiClient _client;
  {{feature_name.pascalCase()}}RemoteDataSource(this._client);

  Future<Result<Failure, {{feature_name.pascalCase()}}Model>> get{{feature_name.pascalCase()}}() {
    // TODO: point this at the real endpoint.
    return _client.get(
      '/{{feature_name.paramCase()}}',
      parser: (json) =>
          {{feature_name.pascalCase()}}Model.fromJson(json as Map<String, dynamic>),
    );
  }
}
