/// Injected by `authentication` (§9/§10) — the concrete `/auth/refresh`
/// call and "force logout" action [RefreshTokenInterceptor] needs. Kept
/// behind this contract for the same reason as `TokenProvider`: `core`/
/// `shared` can't import `authentication` directly (it depends on them)
/// without a circular package dependency, and this callback is invoked
/// through the very `Dio` instance `shared`'s `RegisterModule.dio` builds.
abstract class TokenRefresher {
  /// Calls `/auth/refresh` once and saves the new access token on
  /// success. Reactive-only — triggered by a real 401, never a timer — so
  /// no access-token TTL needs to be known for this to work (see
  /// GAPS.md's TTL entry for why that number is otherwise undeterminable).
  Future<bool> refresh();

  /// Same side effects as a normal user-initiated logout, triggered
  /// reactively when [refresh] itself fails.
  Future<void> forceLogout();
}
