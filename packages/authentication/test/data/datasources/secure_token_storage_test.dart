import 'package:authentication/authentication.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

const _accessTokenKey = 'com.akujamin.mobile.access_token';
const _refreshTokenKey = 'com.akujamin.mobile.refresh_token';
const _cachedUserKey = 'com.akujamin.mobile.cached_user';
const _sessionProfileKey = 'com.akujamin.mobile.session_profile';

void main() {
  late _MockFlutterSecureStorage storage;
  late SecureTokenStorage tokenStorage;

  setUp(() {
    storage = _MockFlutterSecureStorage();
    tokenStorage = SecureTokenStorage(storage);
  });

  test('saveTokens writes both the access and refresh token', () async {
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});

    await tokenStorage.saveTokens(access: 'access-1', refresh: 'refresh-1');

    verify(
      () => storage.write(key: _accessTokenKey, value: 'access-1'),
    ).called(1);
    verify(
      () => storage.write(key: _refreshTokenKey, value: 'refresh-1'),
    ).called(1);
  });

  test('accessToken/refreshToken read straight from storage', () async {
    when(
      () => storage.read(key: _accessTokenKey),
    ).thenAnswer((_) async => 'access-1');
    when(
      () => storage.read(key: _refreshTokenKey),
    ).thenAnswer((_) async => 'refresh-1');

    expect(await tokenStorage.accessToken, 'access-1');
    expect(await tokenStorage.refreshToken, 'refresh-1');
  });

  test('saveAccessToken writes only the access-token key', () async {
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});

    await tokenStorage.saveAccessToken('otp-access-1');

    verify(
      () => storage.write(key: _accessTokenKey, value: 'otp-access-1'),
    ).called(1);
    verifyNever(
      () => storage.write(
        key: _refreshTokenKey,
        value: any(named: 'value'),
      ),
    );
  });

  test('clear deletes everything', () async {
    when(() => storage.deleteAll()).thenAnswer((_) async {});

    await tokenStorage.clear();

    verify(() => storage.deleteAll()).called(1);
  });

  test('saveUser then getCachedUser round-trips the user', () async {
    String? stored;
    when(
      () => storage.write(
        key: _cachedUserKey,
        value: any(named: 'value'),
      ),
    ).thenAnswer((invocation) async {
      stored = invocation.namedArguments[#value] as String;
    });
    when(
      () => storage.read(key: _cachedUserKey),
    ).thenAnswer((_) async => stored);

    const user = User(id: '1', email: 'a@example.com', role: 'admin');
    await tokenStorage.saveUser(user);
    final cached = await tokenStorage.getCachedUser();

    expect(cached, user);
  });

  test('getCachedUser returns null when nothing is cached', () async {
    when(() => storage.read(key: _cachedUserKey)).thenAnswer((_) async => null);

    expect(await tokenStorage.getCachedUser(), isNull);
  });

  test(
    'saveSessionProfile then getCachedSessionProfile round-trips the profile',
    () async {
      String? stored;
      when(
        () => storage.write(
          key: _sessionProfileKey,
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        stored = invocation.namedArguments[#value] as String;
      });
      when(
        () => storage.read(key: _sessionProfileKey),
      ).thenAnswer((_) async => stored);

      const profile = SessionProfile(
        avatar: 'https://example.com/a.png',
        name: 'Ani',
        nik: '1234567890123456',
      );
      await tokenStorage.saveSessionProfile(profile);
      final cached = await tokenStorage.getCachedSessionProfile();

      expect(cached, profile);
    },
  );

  test('getCachedSessionProfile returns null when nothing is cached', () async {
    when(
      () => storage.read(key: _sessionProfileKey),
    ).thenAnswer((_) async => null);

    expect(await tokenStorage.getCachedSessionProfile(), isNull);
  });

  group('clear() against a real (non-mocked) storage backing', () {
    // The tests above mock FlutterSecureStorage itself, so `deleteAll()`
    // "succeeding" only proves the method was called — not that data is
    // actually gone. This group uses the plugin's own official in-memory
    // backing (FlutterSecureStorage.setMockInitialValues, the same
    // mechanism as shared_preferences' setMockInitialValues) so clear()
    // is checked against real read/write/delete behaviour, not an
    // assumption that deleteAll() "should" remove everything.
    test('genuinely removes both the cached user and the session profile, '
        'not just the tokens', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final realTokenStorage = SecureTokenStorage(const FlutterSecureStorage());

      const user = User(id: '1', email: 'a@example.com', role: 'admin');
      const profile = SessionProfile(
        avatar: 'https://example.com/a.png',
        name: 'Ani',
        nik: '1234567890123456',
      );

      await realTokenStorage.saveTokens(
        access: 'access-1',
        refresh: 'refresh-1',
      );
      await realTokenStorage.saveUser(user);
      await realTokenStorage.saveSessionProfile(profile);

      // Sanity check: everything is genuinely there before clear() —
      // otherwise the assertions after clear() would be trivially true.
      expect(await realTokenStorage.accessToken, 'access-1');
      expect(await realTokenStorage.getCachedUser(), user);
      expect(await realTokenStorage.getCachedSessionProfile(), profile);

      await realTokenStorage.clear();

      expect(
        await realTokenStorage.accessToken,
        isNull,
        reason: 'clear() should remove the access token',
      );
      expect(
        await realTokenStorage.getCachedUser(),
        isNull,
        reason: 'clear() should remove the cached user',
      );
      expect(
        await realTokenStorage.getCachedSessionProfile(),
        isNull,
        reason:
            'clear() should remove the session profile (NIK) too — this '
            'is the assertion this test exists for: SessionProfile is '
            'written through the same _storage instance as everything '
            'else in this class, so deleteAll() genuinely reaches it. '
            'If SessionProfile were ever moved to a different storage '
            'mechanism, this test would catch clear() silently leaving '
            'NIK behind after logout.',
      );
    });
  });
}
