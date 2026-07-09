import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/repositories/about_repository.dart';
import 'about_state.dart';

/// No UseCase (§21/ADR-004, see [AboutRepository]'s doc comment) — a plain
/// pass-through to `AboutRepository.getAbout()`, same shape as
/// `ProfileCubit.getProfile()`.
///
/// `core` is imported directly (not just transitively via the repository)
/// because `Result.fold` is an extension method — needs the extension
/// itself in scope (§15).
///
/// The old `AboutStateCubit` had a re-entry guard
/// (`if (state is LoadingAboutState) return;`) against double-taps — not
/// needed here since [AboutPage] calls `getAbout()` exactly once, from
/// `create:`, same as every other migrated feature's page; nothing else in
/// this feature can trigger a second concurrent call.
@injectable
class AboutCubit extends Cubit<AboutState> {
  final AboutRepository _repository;
  AboutCubit(this._repository) : super(const AboutState.initial());

  Future<void> getAbout() async {
    emit(const AboutState.loading());
    final result = await _repository.getAbout();
    result.fold(
      (failure) => emit(AboutState.error(failure)),
      (items) => emit(AboutState.loaded(items)),
    );
  }
}
