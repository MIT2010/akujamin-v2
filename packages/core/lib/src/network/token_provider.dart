/// Thin contract `AuthInterceptor`/`RefreshTokenInterceptor` depend on to
/// read/persist tokens, without `core` knowing *how* they're stored.
/// The concrete implementation (`SecureTokenStorage`, §24) is wired later
/// by whichever package owns `flutter_secure_storage`.
abstract class TokenProvider {
  Future<String?> get accessToken;
  Future<String?> get refreshToken;
  Future<void> saveTokens({required String access, required String refresh});
  Future<void> clear();
}
