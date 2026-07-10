import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// §21 — same justification as [SendOtpUseCase]: the old app's
/// `AuthStateCubit.getToken()`/`_validateOtp()` validates phone+OTP
/// non-empty and prefixes the phone with `62` before calling the API. This
/// is the project's first UseCase covering a genuine write path with real
/// pre-network validation — see MIGRATION_LOG.md's "write-path + UseCase
/// still untested" note, which this (and [SendOtpUseCase]) resolves.
@injectable
class VerifyOtpUseCase implements UseCase<User, VerifyOtpParams> {
  final AuthRepository _repository;

  VerifyOtpUseCase(this._repository);

  @override
  Future<Result<Failure, User>> call(VerifyOtpParams params) async {
    if (params.phoneNumber.isEmpty) {
      return const Err(ValidationFailure('Nomor telepon tidak boleh kosong.'));
    }
    if (params.otpCode.isEmpty) {
      return const Err(ValidationFailure('Kode OTP tidak boleh kosong.'));
    }
    return _repository.verifyOtp(
      phoneNumber: '62${params.phoneNumber}',
      otpCode: params.otpCode,
    );
  }
}

class VerifyOtpParams {
  final String phoneNumber;
  final String otpCode;
  const VerifyOtpParams({required this.phoneNumber, required this.otpCode});
}
