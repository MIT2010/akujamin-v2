import 'package:core/core.dart';
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

  /// Fetched right after a successful [verifyOtp] to get the user fields
  /// the login-otp response doesn't include.
  Future<Result<Failure, UserProfileModel>> getProfile() {
    return _client.get(
      '/auth/me',
      parser: (json) => UserProfileModel.fromJson(json as Map<String, dynamic>),
    );
  }
}
