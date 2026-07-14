import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../models/user_model.dart';
import '../models/user_profile_model.dart';

/// §19 — talks to `/auth/*` through `core`'s one Dio instance. Throws
/// nothing itself; [ApiClient] already converts [DioException] into a
/// typed [Failure] before this ever sees it.
@injectable
class AuthRemoteDataSource {
  final ApiClient _client;
  AuthRemoteDataSource(this._client);

  Future<Result<Failure, UserModel>> login(String email, String password) {
    return _client.post(
      '/auth/login',
      data: {'email': email, 'password': password},
      parser: (json) => UserModel.fromJson(json as Map<String, dynamic>),
    );
  }

  /// Old-app-shaped response: `{"data": {"expires_at": "..."}}`.
  Future<Result<Failure, DateTime>> sendOtp(String phoneNumber) {
    return _client.post(
      '/auth/send-otp',
      data: {'phone_number': phoneNumber},
      parser: (json) => DateTime.parse(
        ((json as Map<String, dynamic>)['data']
                as Map<String, dynamic>)['expires_at']
            as String,
      ),
    );
  }

  /// OTP login returns only an access token (no refresh token, no user) —
  /// see docs/qa/auth_login.md §2. `{"access_token": "..."}`, matching the
  /// old app's flat (non-nested) `login-otp` response.
  Future<Result<Failure, String>> verifyOtp(
    String phoneNumber,
    String otpCode,
  ) {
    return _client.post(
      '/auth/login-otp',
      data: {'phone_number': phoneNumber, 'otp_code': otpCode},
      parser: (json) =>
          (json as Map<String, dynamic>)['access_token'] as String,
    );
  }

  /// `/auth/refresh` — old-app-shaped envelope: `{"status": "ok"|"nok",
  /// "message"?, "access_token": "..."}` (mirrors the legacy app's
  /// `auth_repo_impl.dart` `refreshToken()`, the only concrete evidence of
  /// this endpoint's real response shape — no saved Postman example
  /// exists). Reactive-only, called by `RefreshTokenInterceptor` on a
  /// real 401 (§9/§10) — never on a schedule, so no TTL is needed here.
  Future<Result<Failure, Map<String, dynamic>>> refreshToken() {
    return _client.post(
      '/auth/refresh',
      parser: (json) => json as Map<String, dynamic>,
    );
  }

  /// Fetched right after a successful [verifyOtp] to get the user fields
  /// the login-otp response doesn't include. Also reused by
  /// [AuthRepositoryImpl.refreshProfile] after a successful registration.
  Future<Result<Failure, UserProfileModel>> getProfile() {
    return _client.get(
      '/auth/me',
      parser: (json) => UserProfileModel.fromJson(json as Map<String, dynamic>),
    );
  }

  /// `/registrasi/ktp` — same base path segment the old app used
  /// (`/api/registrasi/ktp`), confirmed against the team's own
  /// `PMI-API.postman_collection.json` (`API V2 > Registrasi > KTP`).
  /// Returns the raw envelope — status-check and unwrapping happen at the
  /// repository layer, same as every other datasource in this codebase.
  Future<Result<Failure, Map<String, dynamic>>> extractKtp(
    List<int> ktpImageBytes,
    List<int> selfieImageBytes,
  ) {
    return _client.multipart<Map<String, dynamic>>(
      '/registrasi/ktp',
      data: FormData.fromMap({
        'ktp': MultipartFile.fromBytes(ktpImageBytes, filename: 'ktp.jpg'),
        'image': MultipartFile.fromBytes(
          selfieImageBytes,
          filename: 'selfie.jpg',
        ),
      }),
      parser: (json) => json as Map<String, dynamic>,
    );
  }

  /// `/registrasi/save` — confirmed against the same Postman collection
  /// (`API V2 > Registrasi > Save Regis`), including the real example
  /// field keys (`tgl_lahir`, `nik`, `foto`, ...) that motivated
  /// `docs/qa/register.md`'s date-format finding.
  Future<Result<Failure, Map<String, dynamic>>> submitRegistration(
    Map<String, String> formData,
    List<int> selfieImageBytes,
  ) {
    return _client.multipart<Map<String, dynamic>>(
      '/registrasi/save',
      data: FormData.fromMap({
        ...formData,
        'foto': MultipartFile.fromBytes(
          selfieImageBytes,
          filename: 'selfie.jpg',
        ),
      }),
      parser: (json) => json as Map<String, dynamic>,
    );
  }
}
