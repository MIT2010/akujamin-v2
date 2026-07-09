import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

import '../models/user_model.dart';

/// §19 — talks to `/auth/login` through `core`'s one Dio instance. Throws
/// nothing itself; [ApiClient] already converts [DioException] into a
/// typed [Failure] before this ever sees it.
@injectable
class AuthRemoteDataSource {
  final ApiClient _client;
  AuthRemoteDataSource(this._client);

  Future<Result<Failure, UserModel>> login(String email, String password) {
    return _client.post(
      '/auth/login',
      data: {'email': email, 'password': password},
      parser: (json) => UserModel.fromJson(json as Map<String, dynamic>),
    );
  }
}
