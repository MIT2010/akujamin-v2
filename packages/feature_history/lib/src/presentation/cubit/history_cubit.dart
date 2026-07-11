import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/repositories/history_repository.dart';
import 'history_state.dart';

/// No UseCase (§21/ADR-004, see [HistoryRepository]'s doc comment) — a
/// plain pass-through to `HistoryRepository.getHistory()`, same shape as
/// `AboutCubit.getAbout()`.
@injectable
class HistoryCubit extends Cubit<HistoryState> {
  final HistoryRepository _repository;
  HistoryCubit(this._repository) : super(const HistoryState.initial());

  Future<void> getHistory() async {
    emit(const HistoryState.loading());
    final result = await _repository.getHistory();
    result.fold(
      (failure) => emit(HistoryState.error(failure)),
      (items) => emit(HistoryState.loaded(items)),
    );
  }
}
