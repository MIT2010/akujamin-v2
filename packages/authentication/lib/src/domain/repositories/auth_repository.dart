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

  /// `/auth/refresh` (§9/§10) — reactive-only, called by
  /// `RefreshTokenInterceptor` on a real 401. Returns a plain `bool` (not
  /// `Result`) because its one caller only needs succeeded-or-not; the
  /// typed `Failure` has nowhere useful to surface to at that layer, same
  /// reasoning as [getCachedUser] below not returning one either.
  Future<bool> refreshToken();
  Future<User?> getCachedUser();
  Future<SessionProfile?> getCachedSessionProfile();

  /// Server-side KTP OCR — sends both images (KTP scan *and* the
  /// already-captured selfie) to the same endpoint, exactly as the old app
  /// does (`_extractKTP` in `register_state_cubit.dart`); the client has no
  /// visibility into why the server wants both (a plausible read is a
  /// face-match check against the KTP photo, same as `test`'s proctoring,
  /// but that's inferred, not confirmed from server behavior). Returns the
  /// raw extracted field map — same shape `formResults` already uses
  /// (label -> value), no invented typed structure where the old app never
  /// had one either.
  Future<Result<Failure, Map<String, String>>> extractKtp({
    required List<int> ktpImageBytes,
    required List<int> selfieImageBytes,
  });

  /// Final registration submit. Pure pass-through at this layer — the real
  /// validation (all fields filled, NIK length) lives in
  /// `CompleteRegistrationUseCase`, not here (§21).
  Future<Result<Failure, void>> submitRegistration({
    required Map<String, String> formData,
    required List<int> selfieImageBytes,
  });

  /// Re-fetches `/auth/me` and persists the refreshed [User]/[SessionProfile]
  /// — same shape as [verifyOtp]'s second half, without the OTP step. Used
  /// after a successful registration to pick up the server's now-`true`
  /// `is_regis` without requiring a fresh login (mirrors the old app's
  /// `HomePage._makeProfile()`, which calls `AuthStateCubit.getProfile()`
  /// again rather than setting the flag locally).
  Future<Result<Failure, (User, SessionProfile)>> refreshProfile();
}
