import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/usecases/send_otp_usecase.dart';
import '../../domain/usecases/verify_otp_usecase.dart';
import 'auth_cubit.dart';
import 'otp_login_state.dart';

/// §22, parallel to [LoginCubit] — does not replace or touch it. Same
/// `AuthCubit.setAuthenticated` integration point on success, so
/// `AppRouter`'s redirect (via `AuthSessionAdapter`) picks up the new
/// session the same way it already does for the email/password flow.
@injectable
class OtpLoginCubit extends Cubit<OtpLoginState> {
  final SendOtpUseCase _sendOtpUseCase;
  final VerifyOtpUseCase _verifyOtpUseCase;
  final AuthCubit _authCubit;

  OtpLoginCubit(this._sendOtpUseCase, this._verifyOtpUseCase, this._authCubit)
    : super(const OtpLoginState.phoneEntry());

  Future<void> sendOtp(String phoneNumber) async {
    emit(const OtpLoginState.sendingOtp());
    final result = await _sendOtpUseCase(
      SendOtpParams(phoneNumber: phoneNumber),
    );
    result.fold(
      (failure) => emit(OtpLoginState.sendOtpFailure(failure)),
      (expiresAt) => emit(
        OtpLoginState.otpEntry(phoneNumber: phoneNumber, expiresAt: expiresAt),
      ),
    );
  }

  Future<void> verifyOtp({
    required String phoneNumber,
    required String otpCode,
    required DateTime expiresAt,
  }) async {
    emit(
      OtpLoginState.verifyingOtp(
        phoneNumber: phoneNumber,
        expiresAt: expiresAt,
      ),
    );
    final result = await _verifyOtpUseCase(
      VerifyOtpParams(phoneNumber: phoneNumber, otpCode: otpCode),
    );
    result.fold(
      (failure) => emit(
        OtpLoginState.verifyOtpFailure(
          failure: failure,
          phoneNumber: phoneNumber,
          expiresAt: expiresAt,
        ),
      ),
      (value) {
        final (user, sessionProfile) = value;
        _authCubit.setAuthenticated(user, sessionProfile: sessionProfile);
        emit(OtpLoginState.success(user));
      },
    );
  }

  /// Lets the OTP-entry screen go back to phone entry (e.g. "ubah nomor").
  void backToPhoneEntry() => emit(const OtpLoginState.phoneEntry());
}
