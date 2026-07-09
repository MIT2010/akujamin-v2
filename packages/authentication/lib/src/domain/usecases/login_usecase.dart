import 'package:core/core.dart';
import 'package:injectable/injectable.dart';
import 'package:shared/shared.dart';

import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// §21 — justified as a UseCase (not a Cubit-calls-repository shortcut,
/// §21's skip rule) because it already orchestrates repository + analytics,
/// and will grow a biometric-prompt step later.
@injectable
class LoginUseCase implements UseCase<User, LoginParams> {
  final AuthRepository _repository;
  final AnalyticsService _analytics;

  LoginUseCase(this._repository, this._analytics);

  @override
  Future<Result<Failure, User>> call(LoginParams params) async {
    final result = await _repository.login(
      email: params.email,
      password: params.password,
    );
    if (result.isOk) await _analytics.logEvent('login_success');
    return result;
  }
}

class LoginParams {
  final String email;
  final String password;
  const LoginParams({required this.email, required this.password});
}
