import 'package:core/core.dart';
import 'package:injectable/injectable.dart';
import 'package:shared/shared.dart';

import '../repositories/auth_repository.dart';

/// §21 — justified as a UseCase, same class as [SendOtpUseCase]/
/// [VerifyOtpUseCase]: the old app's `RegisterStateCubit.doRegister()`
/// really does validate (all schema fields filled, NIK exactly 16 digits)
/// before calling the API — real business rules, not invented ones
/// (`lib/src/features/auth/presentation/blocs/register/
/// register_state_cubit.dart` in the old app, read in full). Ported here,
/// not simplified to a passthrough.
///
/// One correction over the old app: the NIK-length check there computed
/// `state.formResults['nik'].length` *unconditionally*, before checking
/// whether `nik` was even present — a null-check crash waiting to happen
/// if the schema ever omitted it, not just a skipped validation. Here the
/// length is only read once presence is confirmed.
@injectable
class CompleteRegistrationUseCase
    implements UseCase<void, CompleteRegistrationParams> {
  final AuthRepository _repository;

  CompleteRegistrationUseCase(this._repository);

  @override
  Future<Result<Failure, void>> call(CompleteRegistrationParams params) async {
    for (final form in params.forms) {
      if (!params.formResults.containsKey(form.label)) {
        return Err(ValidationFailure('${form.display} masih kosong.'));
      }
    }

    final nik = params.formResults['nik'];
    if (nik != null && nik.length != 16) {
      return const Err(ValidationFailure('Panjang NIK harus 16 digit.'));
    }

    return _repository.submitRegistration(
      formData: params.formResults,
      selfieImageBytes: params.selfieImageBytes,
    );
  }
}

class CompleteRegistrationParams {
  final List<FormInputField> forms;
  final Map<String, String> formResults;
  final List<int> selfieImageBytes;

  const CompleteRegistrationParams({
    required this.forms,
    required this.formResults,
    required this.selfieImageBytes,
  });
}
