import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/repositories/onboarding_repository.dart';
import 'onboarding_state.dart';

/// No UseCase (§21/ADR-004) — both methods are plain pass-throughs to
/// `OnboardingRepository`, same shape as the old app's
/// `GetIsFirstLaunchUsecase`/`SetIsFirstLaunchUsecase` (one-line
/// delegations each). This is the *second* feature to land as a "no
/// UseCase" case (after `about`'s `getAbout()`) — the write-path +
/// UseCase-decision test is still open, tracked explicitly in
/// MIGRATION_LOG.md rather than left implicit.
///
/// `core` is imported directly (not just transitively via the repository)
/// because `Result.fold` is an extension method — needs the extension
/// itself in scope (§15).
///
/// Exercises *both* repository methods, unlike a minimal port would:
/// `checkStatus()` reads the flag to decide whether to show the carousel
/// at all (`alreadyCompleted` short-circuits it), `complete()` writes it
/// once the user finishes. The old app's `OnboardingPage` never read the
/// flag itself (always showed the carousel unconditionally) — this is new
/// behavior, added specifically so this migrated feature actually proves
/// the read side of the local-storage repository too, not just the write
/// side `complete()` alone would cover.
@injectable
class OnboardingCubit extends Cubit<OnboardingState> {
  final OnboardingRepository _repository;
  OnboardingCubit(this._repository) : super(const OnboardingState.checking());

  Future<void> checkStatus() async {
    emit(const OnboardingState.checking());
    final result = await _repository.getIsFirstLaunch();
    result.fold(
      (failure) => emit(OnboardingState.error(failure)),
      (isFirstLaunch) => emit(
        isFirstLaunch
            ? const OnboardingState.showCarousel()
            : const OnboardingState.alreadyCompleted(),
      ),
    );
  }

  Future<void> complete() async {
    emit(const OnboardingState.completing());
    final result = await _repository.setIsFirstLaunch();
    result.fold(
      (failure) => emit(OnboardingState.error(failure)),
      (_) => emit(const OnboardingState.finished()),
    );
  }
}
