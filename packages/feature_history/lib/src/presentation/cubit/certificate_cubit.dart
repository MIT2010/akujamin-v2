import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/repositories/certificate_repository.dart';
import 'certificate_state.dart';

/// No UseCase (§21/ADR-004) — plain pass-through to
/// `CertificateRepository.download()`, same shape as `HistoryCubit`.
@injectable
class CertificateCubit extends Cubit<CertificateState> {
  final CertificateRepository _repository;
  CertificateCubit(this._repository) : super(const CertificateState.initial());

  Future<void> load(String url) async {
    emit(const CertificateState.loading());
    final result = await _repository.download(url);
    result.fold(
      (failure) => emit(CertificateState.error(failure)),
      (bytes) => emit(CertificateState.loaded(bytes)),
    );
  }
}
