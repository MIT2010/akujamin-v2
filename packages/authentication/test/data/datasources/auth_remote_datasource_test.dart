import 'package:authentication/authentication.dart';
import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockApiClient client;
  late AuthRemoteDataSource dataSource;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(FormData());
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

  test('getProfile fetches /auth/me and unwraps the real nested envelope — '
      'every field lives under data except is_regis, which is a sibling '
      '(confirmed against the real backend 2026-07-15, Permanent Finding '
      '#10)', () async {
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
          'status': 'ok',
          'message': 'Data ditemukan',
          'data': {
            'id': 1,
            'email': 'a@example.com',
            'name': 'Ani',
            'avatars': 'https://example.com/a.png',
            'nik': '1234567890123456',
          },
          'is_regis': true,
        }),
      );
    });

    final result = await dataSource.getProfile();

    expect(result.isOk, isTrue);
    final value = (result as Ok<Failure, UserProfileModel>).value;
    expect(value.id, '1');
    expect(value.avatar, 'https://example.com/a.png');
    expect(value.nik, '1234567890123456');
    expect(value.isRegistered, isTrue);
  });

  test('extractKtp posts to /registrasi/ktp with the ktp and image multipart '
      'fields, returns the raw envelope', () async {
    when(
      () => client.multipart<Map<String, dynamic>>(
        '/registrasi/ktp',
        data: any(named: 'data'),
        parser: any(named: 'parser'),
      ),
    ).thenAnswer((invocation) async {
      final parser =
          invocation.namedArguments[#parser]
              as Map<String, dynamic> Function(dynamic);
      return Ok(
        parser({
          'status': 'ok',
          'data': {'name': 'MIRA SETIAWAN', 'nik': '31712345678111'},
        }),
      );
    });

    final result = await dataSource.extractKtp([1, 2, 3], [4, 5, 6]);

    expect(result.isOk, isTrue);
    final envelope = (result as Ok<Failure, Map<String, dynamic>>).value;
    expect(envelope['status'], 'ok');

    final captured =
        verify(
              () => client.multipart<Map<String, dynamic>>(
                '/registrasi/ktp',
                data: captureAny(named: 'data'),
                parser: any(named: 'parser'),
              ),
            ).captured.single
            as FormData;
    expect(captured.files.map((e) => e.key), containsAll(['ktp', 'image']));
  });

  test('submitRegistration posts to /registrasi/save with the form fields '
      'plus a foto multipart field', () async {
    when(
      () => client.multipart<Map<String, dynamic>>(
        '/registrasi/save',
        data: any(named: 'data'),
        parser: any(named: 'parser'),
      ),
    ).thenAnswer((invocation) async {
      final parser =
          invocation.namedArguments[#parser]
              as Map<String, dynamic> Function(dynamic);
      return Ok(parser({'status': 'ok'}));
    });

    final result = await dataSource.submitRegistration(
      {'nik': '31712345678111', 'tgl_lahir': '1986-02-18'},
      [4, 5, 6],
    );

    expect(result.isOk, isTrue);

    final captured =
        verify(
              () => client.multipart<Map<String, dynamic>>(
                '/registrasi/save',
                data: captureAny(named: 'data'),
                parser: any(named: 'parser'),
              ),
            ).captured.single
            as FormData;
    final fieldsMap = {for (final e in captured.fields) e.key: e.value};
    expect(fieldsMap['nik'], '31712345678111');
    expect(fieldsMap['tgl_lahir'], '1986-02-18');
    expect(captured.files.map((e) => e.key), contains('foto'));
  });
}
