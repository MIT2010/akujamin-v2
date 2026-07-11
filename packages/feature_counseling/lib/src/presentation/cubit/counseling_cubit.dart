import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/repositories/counseling_repository.dart';
import 'counseling_state.dart';

/// No UseCase (§21/ADR-004) — plain pass-through to
/// `CounselingRepository.getSessions()`, same shape as `HistoryCubit`.
@injectable
class CounselingCubit extends Cubit<CounselingState> {
  final CounselingRepository _repository;
  CounselingCubit(this._repository) : super(const CounselingState.initial());

  Future<void> getSessions() async {
    if (state is CounselingLoading) return;

    emit(const CounselingState.loading());
    final result = await _repository.getSessions();
    result.fold(
      (failure) => emit(CounselingState.error(failure)),
      (sessions) => emit(CounselingState.loaded(sessions)),
    );
  }
}
