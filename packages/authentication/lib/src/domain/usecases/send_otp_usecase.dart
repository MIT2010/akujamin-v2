import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

import '../repositories/auth_repository.dart';

/// §21 — justified as a UseCase, not a Cubit-calls-repository skip: the old
/// app's `AuthStateCubit.sendOTP()`/`_validatePhone()` really does validate
/// the phone number (non-empty, minimum length) and prefix it with the
/// `62` country code *before* calling the API — real business rules, not
/// invented ones (`lib/src/core/shared/blocs/auth/auth_state_cubit.dart` in
/// the old app, read in full).
@injectable
class SendOtpUseCase implements UseCase<DateTime, SendOtpParams> {
  final AuthRepository _repository;

  SendOtpUseCase(this._repository);

  @override
  Future<Result<Failure, DateTime>> call(SendOtpParams params) async {
    final phone = params.phoneNumber;
    if (phone.isEmpty) {
      return const Err(ValidationFailure('Nomor telepon tidak boleh kosong.'));
    }
    if (phone.length < 9) {
      return const Err(ValidationFailure('Nomor telepon minimal 9 digit.'));
    }
    return _repository.sendOtp(phoneNumber: '62$phone');
  }
}

class SendOtpParams {
  final String phoneNumber;
  const SendOtpParams({required this.phoneNumber});
}
