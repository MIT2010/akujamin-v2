import 'package:authentication/authentication.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockApiClient client;
  late AuthRemoteDataSource dataSource;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    client = _MockApiClient();
    dataSource = AuthRemoteDataSource(client);
  });

  test(
    'login posts to /auth/login with the given credentials and parses the body',
    () async {
      const model = UserModel(
        id: '1',
        email: 'a@example.com',
        role: 'admin',
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
      );

      when(
        () => client.post<UserModel>(
          '/auth/login',
          data: any(named: 'data'),
          parser: any(named: 'parser'),
        ),
      ).thenAnswer((invocation) async {
        final parser =
            invocation.namedArguments[#parser] as UserModel Function(dynamic);
        return Ok(parser(model.toJson()));
      });

      final result = await dataSource.login('a@example.com', 'secret');

      expect(result.isOk, isTrue);
      expect((result as Ok<Failure, UserModel>).value, model);

      final captured = verify(
        () => client.post<UserModel>(
          '/auth/login',
          data: captureAny(named: 'data'),
          parser: any(named: 'parser'),
        ),
      ).captured.single;
      expect(captured, {'email': 'a@example.com', 'password': 'secret'});
    },
  );

  test('sendOtp posts to /auth/send-otp and parses expires_at', () async {
    when(
      () => client.post<DateTime>(
        '/auth/send-otp',
        data: any(named: 'data'),
        parser: any(named: 'parser'),
      ),
    ).thenAnswer((invocation) async {
      final parser =
          invocation.namedArguments[#parser] as DateTime Function(dynamic);
      return Ok(
        parser({
          'data': {'expires_at': '2026-07-10T12:00:00.000Z'},
        }),
      );
    });

    final result = await dataSource.sendOtp('81234567890');

    expect(result.isOk, isTrue);
    expect(
      (result as Ok<Failure, DateTime>).value,
      DateTime.parse('2026-07-10T12:00:00.000Z'),
    );

    final captured = verify(
      () => client.post<DateTime>(
        '/auth/send-otp',
        data: captureAny(named: 'data'),
        parser: any(named: 'parser'),
      ),
    ).captured.single;
    expect(captured, {'phone_number': '81234567890'});
  });

  test(
    'verifyOtp posts to /auth/login-otp and parses the access token',
    () async {
      when(
        () => client.post<String>(
          '/auth/login-otp',
          data: any(named: 'data'),
          parser: any(named: 'parser'),
        ),
      ).thenAnswer((invocation) async {
        final parser =
            invocation.namedArguments[#parser] as String Function(dynamic);
        return Ok(parser({'access_token': 'otp-access-1'}));
      });

      final result = await dataSource.verifyOtp('6281234567890', '123456');

      expect(result.isOk, isTrue);
      expect((result as Ok<Failure, String>).value, 'otp-access-1');

      final captured = verify(
        () => client.post<String>(
          '/auth/login-otp',
          data: captureAny(named: 'data'),
          parser: any(named: 'parser'),
        ),
      ).captured.single;
      expect(captured, {'phone_number': '6281234567890', 'otp_code': '123456'});
    },
  );

  test('getProfile fetches /auth/me and parses the body', () async {
    when(
      () => client.get<UserProfileModel>(
        '/auth/me',
        query: any(named: 'query'),
        parser: any(named: 'parser'),
      ),
    ).thenAnswer((invocation) async {
      final parser =
          invocation.namedArguments[#parser]
              as UserProfileModel Function(dynamic);
      return Ok(
        parser({
          'id': '1',
          'email': 'a@example.com',
          'role': 'admin',
          'name': 'Ani',
          'avatars': 'https://example.com/a.png',
          'nik': '1234567890123456',
        }),
      );
    });

    final result = await dataSource.getProfile();

    expect(result.isOk, isTrue);
    final value = (result as Ok<Failure, UserProfileModel>).value;
    expect(value.id, '1');
    expect(value.avatar, 'https://example.com/a.png');
    expect(value.nik, '1234567890123456');
  });
}
