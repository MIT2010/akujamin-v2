import 'package:core/core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/profile.dart';

part 'profile_state.freezed.dart';

/// freezed 3.x requires `sealed class` for union types with multiple
/// factory constructors (ADR-005).
///
/// `saving` is its own state, not folded into `loading` — the UX differs
/// (`loading`: full-screen spinner, nothing else on screen yet; `saving`:
/// the form the user already sees stays visible, just with the Save
/// button disabled and a small spinner). It carries the in-flight
/// [Profile] so the form has something to keep rendering while the
/// request is out.
@freezed
sealed class ProfileState with _$ProfileState {
  const factory ProfileState.initial() = ProfileInitial;
  const factory ProfileState.loading() = ProfileLoading;
  const factory ProfileState.loaded(Profile profile) = ProfileLoaded;
  const factory ProfileState.saving(Profile profile) = ProfileSaving;
  const factory ProfileState.error(Failure failure) = ProfileError;
}
