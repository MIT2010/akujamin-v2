import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/update_profile_usecase.dart';
import 'profile_state.dart';

/// No UseCase for `getProfile()` (§21/ADR-004): a plain pass-through to
/// `ProfileRepository.getProfile()`, no orchestration to name. `updateProfile()`
/// goes through [UpdateProfileUseCase] instead, since *that* one really does
/// orchestrate repository + analytics — see the UseCase's own doc comment.
///
/// `core` is imported directly (not just transitively via the repository/
/// use case) because `Result.fold` is an extension method — those need the
/// extension itself in scope, not just the type it applies to (§15, same
/// fix `HomeCubit` needed).
@injectable
class ProfileCubit extends Cubit<ProfileState> {
  final ProfileRepository _repository;
  final UpdateProfileUseCase _updateProfileUseCase;

  ProfileCubit(this._repository, this._updateProfileUseCase)
    : super(const ProfileState.initial());

  Future<void> getProfile() async {
    emit(const ProfileState.loading());
    final result = await _repository.getProfile();
    result.fold(
      (failure) => emit(ProfileState.error(failure)),
      (profile) => emit(ProfileState.loaded(profile)),
    );
  }

  Future<void> updateProfile(Profile profile) async {
    emit(ProfileState.saving(profile));
    final result = await _updateProfileUseCase(profile);
    result.fold(
      (failure) => emit(ProfileState.error(failure)),
      (updated) => emit(ProfileState.loaded(updated)),
    );
  }
}
