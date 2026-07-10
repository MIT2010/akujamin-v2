import 'package:authentication/authentication.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class _MockSecureTokenStorage extends Mock implements SecureTokenStorage {}

void main() {
  late _MockAuthRemoteDataSource remote;
  late _MockSecureTokenStorage tokenStorage;
  late AuthRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(const User(id: '', email: '', role: ''));
    registerFallbackValue(const SessionProfile(avatar: '', name: '', nik: ''));
  });

  setUp(() {
    remote = _MockAuthRemoteDataSource();
    tokenStorage = _MockSecureTokenStorage();
    repository = AuthRepositoryImpl(remote, tokenStorage);
  });

  const model = UserModel(
    id: '1',
    email: 'a@example.com',
    role: 'admin',
    accessToken: 'access-123',
    refreshToken: 'refresh-456',
  );

  group('AuthRepositoryImpl.login', () {
    test('saves the tokens and the user, then returns Ok on success', () async {
      when(
        () => remote.login('a@example.com', 'secret'),
      ).thenAnswer((_) async => const Ok(model));
      when(
        () => tokenStorage.saveTokens(
          access: any(named: 'access'),
          refresh: any(named: 'refresh'),
        ),
      ).thenAnswer((_) async {});
      when(() => tokenStorage.saveUser(any())).thenAnswer((_) async {});

      final result = await repository.login(
        email: 'a@example.com',
        password: 'secret',
      );

      expect(result.isOk, isTrue);
      expect((result as Ok<Failure, User>).value.id, '1');
      verify(
        () => tokenStorage.saveTokens(
          access: 'access-123',
          refresh: 'refresh-456',
        ),
      ).called(1);
      verify(() => tokenStorage.saveUser(any())).called(1);
    });

    test('returns Err and never touches token storage on failure', () async {
      when(
        () => remote.login(any(), any()),
      ).thenAnswer((_) async => const Err(UnauthorizedFailure()));

      final result = await repository.login(
        email: 'a@example.com',
        password: 'wrong',
      );

      expect(result.isErr, isTrue);
      expect(
        (result as Err<Failure, User>).failure,
        isA<UnauthorizedFailure>(),
      );
      verifyNever(
        () => tokenStorage.saveTokens(
          access: any(named: 'access'),
          refresh: any(named: 'refresh'),
        ),
      );
      verifyNever(() => tokenStorage.saveUser(any()));
    });
  });

  group('AuthRepositoryImpl.sendOtp', () {
    test('delegates straight to the remote data source', () async {
      final expiresAt = DateTime.parse('2026-07-10T12:00:00.000Z');
      when(
        () => remote.sendOtp('6281234567890'),
      ).thenAnswer((_) async => Ok(expiresAt));

      final result = await repository.sendOtp(phoneNumber: '6281234567890');

      expect(result.isOk, isTrue);
      expect((result as Ok<Failure, DateTime>).value, expiresAt);
    });
  });

  group('AuthRepositoryImpl.verifyOtp', () {
    const profile = UserProfileModel(
      id: '1',
      email: 'a@example.com',
      role: 'admin',
      name: 'Ani',
      avatar: 'https://example.com/a.png',
      nik: '1234567890123456',
    );

    test('saves the access token, the user and the session profile, then '
        'returns Ok on success', () async {
      when(
        () => remote.verifyOtp('6281234567890', '123456'),
      ).thenAnswer((_) async => const Ok('otp-access-1'));
      when(() => tokenStorage.saveAccessToken(any())).thenAnswer((_) async {});
      when(
        () => remote.getProfile(),
      ).thenAnswer((_) async => const Ok(profile));
      when(() => tokenStorage.saveUser(any())).thenAnswer((_) async {});
      when(
        () => tokenStorage.saveSessionProfile(any()),
      ).thenAnswer((_) async {});

      final result = await repository.verifyOtp(
        phoneNumber: '6281234567890',
        otpCode: '123456',
      );

      expect(result.isOk, isTrue);
      final (user, sessionProfile) =
          (result as Ok<Failure, (User, SessionProfile)>).value;
      expect(user.id, '1');
      expect(sessionProfile.nik, '1234567890123456');
      expect(sessionProfile.avatar, 'https://example.com/a.png');
      expect(sessionProfile.name, 'Ani');
      verify(() => tokenStorage.saveAccessToken('otp-access-1')).called(1);
      verify(() => tokenStorage.saveUser(any())).called(1);
      verify(() => tokenStorage.saveSessionProfile(any())).called(1);
    });

    test(
      'returns Err and never fetches the profile when verify fails',
      () async {
        when(
          () => remote.verifyOtp(any(), any()),
        ).thenAnswer((_) async => const Err(UnauthorizedFailure()));

        final result = await repository.verifyOtp(
          phoneNumber: '6281234567890',
          otpCode: 'wrong',
        );

        expect(result.isErr, isTrue);
        expect(
          (result as Err<Failure, (User, SessionProfile)>).failure,
          isA<UnauthorizedFailure>(),
        );
        verifyNever(() => tokenStorage.saveAccessToken(any()));
        verifyNever(() => remote.getProfile());
      },
    );

    test(
      'returns Err when the token verifies but the profile fetch fails',
      () async {
        when(
          () => remote.verifyOtp(any(), any()),
        ).thenAnswer((_) async => const Ok('otp-access-1'));
        when(
          () => tokenStorage.saveAccessToken(any()),
        ).thenAnswer((_) async {});
        when(
          () => remote.getProfile(),
        ).thenAnswer((_) async => const Err(NetworkFailure()));

        final result = await repository.verifyOtp(
          phoneNumber: '6281234567890',
          otpCode: '123456',
        );

        expect(result.isErr, isTrue);
        verifyNever(() => tokenStorage.saveUser(any()));
        verifyNever(() => tokenStorage.saveSessionProfile(any()));
      },
    );
  });

  group('AuthRepositoryImpl.logout', () {
    test('clears token storage and returns Ok', () async {
      when(() => tokenStorage.clear()).thenAnswer((_) async {});

      final result = await repository.logout();

      expect(result.isOk, isTrue);
      verify(() => tokenStorage.clear()).called(1);
    });
  });

  group('AuthRepositoryImpl.getCachedUser', () {
    test('delegates straight to token storage', () async {
      when(() => tokenStorage.getCachedUser()).thenAnswer(
        (_) async => const User(id: '1', email: 'a@example.com', role: 'admin'),
      );

      final user = await repository.getCachedUser();

      expect(user?.id, '1');
    });

    test('returns null when nothing is cached', () async {
      when(() => tokenStorage.getCachedUser()).thenAnswer((_) async => null);

      final user = await repository.getCachedUser();

      expect(user, isNull);
    });
  });
}
