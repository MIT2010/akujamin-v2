import 'package:core/core.dart';

import '../entities/session_profile.dart';
import '../entities/user.dart';

/// Abstract contract (§18) — the domain layer defines *what* the app does,
/// never *how*. Implemented by [AuthRepositoryImpl] in the data layer.
abstract class AuthRepository {
  Future<Result<Failure, User>> login({
    required String email,
    required String password,
  });

  /// Returns the OTP's expiry, so the UI can show a resend/expiry window.
  Future<Result<Failure, DateTime>> sendOtp({required String phoneNumber});

  /// Verifies the code, then fetches the profile the login-otp response
  /// doesn't include (see [AuthRepositoryImpl.verifyOtp]). Returns both
  /// [User] (auth/session identity) and [SessionProfile] (display-only
  /// fields, deliberately kept separate — see [SessionProfile]'s doc
  /// comment) from that one fetch.
  Future<Result<Failure, (User, SessionProfile)>> verifyOtp({
    required String phoneNumber,
    required String otpCode,
  });

  Future<Result<Failure, void>> logout();
  Future<User?> getCachedUser();
  Future<SessionProfile?> getCachedSessionProfile();
}
