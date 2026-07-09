import 'package:core/core.dart';
import 'package:injectable/injectable.dart';
import 'package:shared/shared.dart';

import '../entities/profile.dart';
import '../repositories/profile_repository.dart';

/// §21 — justified as a UseCase (not the Cubit-calls-repository shortcut):
/// orchestrates `repository.updateProfile()` + a `profile_updated` analytics
/// event on success, the identical shape to `authentication`'s
/// `LoginUseCase`. This is the counterpart case to `feature_home`, which
/// skips a UseCase for `getFeed()` because there's no orchestration to name
/// there — `getProfile()` here is the same story (see [ProfileCubit]):
/// a plain pass-through gets no UseCase, an orchestrated write does.
@injectable
class UpdateProfileUseCase implements UseCase<Profile, Profile> {
  final ProfileRepository _repository;
  final AnalyticsService _analytics;

  UpdateProfileUseCase(this._repository, this._analytics);

  @override
  Future<Result<Failure, Profile>> call(Profile params) async {
    final result = await _repository.updateProfile(params);
    if (result.isOk) await _analytics.logEvent('profile_updated');
    return result;
  }
}
