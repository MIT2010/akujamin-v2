import 'dart:convert';
import 'dart:typed_data';

import 'package:authentication/authentication.dart';
import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/di/injection.dart';
import 'package:shared/shared.dart' show getIt;
import 'package:shared_preferences/shared_preferences.dart';

/// Plain `test()`, not `testWidgets()` — a real finding while building this:
/// `flutter_test`'s `AutomatedTestWidgetsFlutterBinding` hangs indefinitely
/// on a genuine Dio request/response round trip, even one fully backed by
/// an in-memory fake `HttpClientAdapter` with zero real I/O. Proven with a
/// throwaway debug test (deleted after use): the identical Dio call
/// resolves instantly under plain `test()`, and hangs to the 10-minute
/// framework timeout under `testWidgets()`. Every other full-DI test in
/// this directory (`app_session_gate_test.dart`, `widget_test.dart`) never
/// makes a real Dio call — only secure-storage reads and routing — so this
/// is the first test to hit it, not a regression those introduced.
///
/// Records every request `shared`'s real Dio instance sends through it and
/// answers with a scripted 401-then-200 sequence, proving the *wired*
/// interceptor chain (`AuthInterceptor` + `RefreshTokenInterceptor`, both
/// attached in `RegisterModule.dio` — see MIGRATION_LOG.md's `auth` row) —
/// not just each interceptor's own isolated unit test
/// (`refresh_token_interceptor_test.dart` in `packages/core`, which fakes
/// its callbacks rather than exercising a real `AuthRepository`/`AuthCubit`
/// chain end to end).
///
/// The "refresh itself fails -> force logout" half of the user's ask is
/// covered at the unit level instead
/// (`auth_cubit_test.dart`'s `forceLogout()` group +
/// `auth_repository_impl_test.dart`'s `refreshToken` failure cases) — a
/// full-DI run of `AuthCubit.logout()` here would also invoke the real
/// `flutter_local_notifications` plugin channel (`cancelAll()`), which has
/// no test-mode handler and throws `MissingPluginException` (a separate,
/// pre-existing test-environment gap unrelated to the refresh flow itself,
/// not worth conflating with this test).
/// Dio reuses the *same* `RequestOptions` object for a retried request
/// (`RefreshTokenInterceptor` does `err.requestOptions..extra[...] = true`,
/// never a copy) — `AuthInterceptor.onRequest` then overwrites its
/// `Authorization` header in place on replay. Storing the object itself
/// would make every recorded entry show the *final* header value once the
/// whole exchange settles, not what it was at the moment each request was
/// actually sent — so this records the path + header as plain strings at
/// call time instead, a real snapshot per call.
class _RecordedRequest {
  _RecordedRequest(this.path, this.authorization);
  final String path;
  final String? authorization;
}

class _RecordingRefreshAdapter implements HttpClientAdapter {
  final List<_RecordedRequest> requests = [];
  var _protectedCallCount = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(
      _RecordedRequest(options.path, options.headers['Authorization']),
    );

    if (options.path.contains('/auth/refresh')) {
      return ResponseBody.fromString(
        jsonEncode({'status': 'ok', 'access_token': 'fresh-access-token'}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    _protectedCallCount++;
    if (_protectedCallCount == 1) {
      return ResponseBody.fromString('{}', 401);
    }
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => getIt.reset());

  test('a real 401 through the real DI-wired Dio instance triggers a reactive '
      'refresh (§9/§10) and transparently retries the original request with '
      'the new access token — proving RefreshTokenInterceptor is actually '
      'attached in shared/RegisterModule.dio, not just unit-tested in '
      'isolation', () async {
    FlutterSecureStorage.setMockInitialValues({
      'com.akujamin.mobile.access_token': 'stale-access-token',
      'com.akujamin.mobile.cached_user': jsonEncode({
        'id': '1',
        'email': 'a@example.com',
        'role': 'peserta',
        'isRegistered': true,
      }),
    });

    await configureDependencies(env: Env.current);
    // AuthCubit is a lazy singleton -- getIt<AuthCubit>() here forces
    // construction (kicking off its constructor's un-awaited
    // _restoreCachedSession()) up front, so the pumpEventQueue() below has
    // an actual instance to settle. Without this, the listener attached
    // further down would be the thing that first constructs the cubit,
    // making the boot-time restore's own authenticated() emission race
    // ahead of it instead.
    final authCubit = getIt<AuthCubit>();
    await pumpEventQueue();

    final dio = getIt<Dio>();
    final adapter = _RecordingRefreshAdapter();
    dio.httpClientAdapter = adapter;

    // Real bug, found 2026-07-17 from live testing: AuthCubit.refresh()
    // used to leave `state` untouched during the call, so there was
    // nothing distinguishing "a refresh is in progress" from any other
    // silent background request -- and nothing shown while waiting.
    // Captured here through the *real*, DI-wired AuthCubit (not a mock),
    // proving the full chain -- RefreshTokenInterceptor calling into
    // AuthCubit.refresh(), which emits refreshing() then authenticated()
    // -- actually fires end to end, not just each piece in isolation.
    final authStates = <AuthState>[];
    final authSub = authCubit.stream.listen(authStates.add);

    final result = await getIt<ApiClient>().get<Map<String, dynamic>>(
      '/protected/ping',
      parser: (json) => json as Map<String, dynamic>,
    );
    await authSub.cancel();

    expect(result.isOk, isTrue);
    expect((result as Ok<Failure, Map<String, dynamic>>).value['ok'], true);

    // Exactly 3 requests went out: the original (401), the refresh call,
    // and the retried original (200) — not an unbounded retry loop.
    expect(adapter.requests, hasLength(3));
    expect(
      adapter.requests[0].authorization,
      'Bearer stale-access-token',
      reason:
          'the original request must carry the token that was live '
          'at the time it was first sent, not what it ends up as after '
          'the retry — RequestOptions is mutated in place, so this must '
          'be a snapshot captured at send time, not read back after',
    );
    expect(adapter.requests[1].path, contains('/auth/refresh'));
    expect(
      adapter.requests[2].authorization,
      'Bearer fresh-access-token',
      reason:
          'the retried request must carry the NEW token AuthInterceptor '
          'reads fresh from TokenProvider on replay, not the stale one '
          'baked into the failed request it is replaying',
    );

    // A successful refresh must never force a logout.
    expect(authCubit.state, isA<AuthAuthenticated>());

    // ...and must show a splash while waiting, not jump straight to
    // /login and never come back -- see apps/mobile/lib/src/app.dart's
    // top-level BlocBuilder, which gates on AuthRefreshing the same way
    // it already did on AuthInitial.
    expect(authStates, [isA<AuthRefreshing>(), isA<AuthAuthenticated>()]);
  });
}
