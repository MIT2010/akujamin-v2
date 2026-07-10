import 'package:core/core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/user.dart';

part 'otp_login_state.freezed.dart';

/// §22 — a union of 7 states covering both screens of the phone→OTP flow
/// (mirrors the old app's `AuthStatus` enum,
/// `lib/src/core/shared/blocs/auth/auth_state.dart`, minus the countdown
/// timer — see docs/qa/auth_login.md). `sealed` + native `switch` per
/// ADR-005, same as [LoginState].
@freezed
sealed class OtpLoginState with _$OtpLoginState {
  const factory OtpLoginState.phoneEntry() = OtpLoginPhoneEntry;
  const factory OtpLoginState.sendingOtp() = OtpLoginSendingOtp;
  const factory OtpLoginState.sendOtpFailure(Failure failure) =
      OtpLoginSendOtpFailure;
  const factory OtpLoginState.otpEntry({
    required String phoneNumber,
    required DateTime expiresAt,
  }) = OtpLoginOtpEntry;
  const factory OtpLoginState.verifyingOtp({
    required String phoneNumber,
    required DateTime expiresAt,
  }) = OtpLoginVerifyingOtp;
  const factory OtpLoginState.verifyOtpFailure({
    required Failure failure,
    required String phoneNumber,
    required DateTime expiresAt,
  }) = OtpLoginVerifyOtpFailure;
  const factory OtpLoginState.success(User user) = OtpLoginSuccessState;
}
