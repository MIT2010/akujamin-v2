import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/repositories/home_repository.dart';
import 'home_state.dart';

/// No UseCase here (§21/ADR-004): `loadFeed` is a straight pass-through to
/// `HomeRepository.getFeed()` with zero orchestration — no analytics, no
/// combining multiple repositories, no business rule to name. If this Cubit
/// ever grows a second dependency or a real rule, *that's* the signal to
/// promote it to a UseCase, not before.
///
/// `core` is imported directly (not just transitively via
/// `home_repository.dart`) because `Result.fold` is an extension method —
/// those need the extension itself in scope, not just the type it applies
/// to (§15, same as `LoginCubit`).
@injectable
class HomeCubit extends Cubit<HomeState> {
  final HomeRepository _repository;

  HomeCubit(this._repository) : super(const HomeState.initial());

  Future<void> loadFeed() async {
    emit(const HomeState.loading());
    final result = await _repository.getFeed();
    result.fold(
      (failure) => emit(HomeState.error(failure)),
      (feed) => emit(HomeState.loaded(feed.items, isStale: feed.isStale)),
    );
  }
}
