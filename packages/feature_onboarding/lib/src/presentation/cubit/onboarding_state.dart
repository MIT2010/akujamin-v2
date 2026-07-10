import 'package:core/core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_state.freezed.dart';

/// freezed 3.x `sealed class` for the state union (ADR-005). No direct old-
/// app equivalent (the old `OnboardingPage` had no state machine at all —
/// it just showed the carousel unconditionally); this is new structure
/// introduced to genuinely exercise both `OnboardingRepository` methods
/// within the feature's own UI (`checking`/`showCarousel`/
/// `alreadyCompleted` read the flag, `completing`/`finished` write it) —
/// see [OnboardingCubit]'s doc comment for why.
@freezed
sealed class OnboardingState with _$OnboardingState {
  const factory OnboardingState.checking() = OnboardingChecking;
  const factory OnboardingState.showCarousel() = OnboardingShowCarousel;
  const factory OnboardingState.alreadyCompleted() = OnboardingAlreadyCompleted;
  const factory OnboardingState.completing() = OnboardingCompleting;
  const factory OnboardingState.finished() = OnboardingFinished;
  const factory OnboardingState.error(Failure failure) = OnboardingError;
}
