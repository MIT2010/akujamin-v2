import 'package:authentication/authentication.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;
  late VerifyOtpUseCase useCase;

  setUp(() {
    repository = _MockAuthRepository();
    useCase = VerifyOtpUseCase(repository);
  });

  const user = User(id: '1', email: 'a@example.com', role: 'admin');
  const sessionProfile = SessionProfile(
    avatar: 'https://example.com/a.png',
    name: 'Ani',
    nik: '1234567890123456',
  );

  test(
    'prefixes the phone number with 62 and delegates to the repository',
    () async {
      when(
        () => repository.verifyOtp(
          phoneNumber: '6281234567890',
          otpCode: '123456',
        ),
      ).thenAnswer((_) async => const Ok((user, sessionProfile)));

      final result = await useCase(
        const VerifyOtpParams(phoneNumber: '81234567890', otpCode: '123456'),
      );

      expect(result.isOk, isTrue);
      verify(
        () => repository.verifyOtp(
          phoneNumber: '6281234567890',
          otpCode: '123456',
        ),
      ).called(1);
    },
  );

  test('strips a leading 0 before prefixing with 62 -- real bug, found '
      '2026-07-16: typing a phone number the normal Indonesian way '
      '(leading 0) used to produce a malformed 62081234567890', () async {
    when(
      () =>
          repository.verifyOtp(phoneNumber: '6281234567890', otpCode: '123456'),
    ).thenAnswer((_) async => const Ok((user, sessionProfile)));

    final result = await useCase(
      const VerifyOtpParams(phoneNumber: '081234567890', otpCode: '123456'),
    );

    expect(result.isOk, isTrue);
    verify(
      () =>
          repository.verifyOtp(phoneNumber: '6281234567890', otpCode: '123456'),
    ).called(1);
  });

  test(
    'returns a ValidationFailure without calling the repository when the phone is empty',
    () async {
      final result = await useCase(
        const VerifyOtpParams(phoneNumber: '', otpCode: '123456'),
      );

      expect(result.isErr, isTrue);
      expect(
        (result as Err<Failure, (User, SessionProfile)>).failure,
        isA<ValidationFailure>(),
      );
      verifyNever(
        () => repository.verifyOtp(
          phoneNumber: any(named: 'phoneNumber'),
          otpCode: any(named: 'otpCode'),
        ),
      );
    },
  );

  test(
    'returns a ValidationFailure without calling the repository when the OTP is empty',
    () async {
      final result = await useCase(
        const VerifyOtpParams(phoneNumber: '81234567890', otpCode: ''),
      );

      expect(result.isErr, isTrue);
      expect(
        (result as Err<Failure, (User, SessionProfile)>).failure,
        isA<ValidationFailure>(),
      );
      verifyNever(
        () => repository.verifyOtp(
          phoneNumber: any(named: 'phoneNumber'),
          otpCode: any(named: 'otpCode'),
        ),
      );
    },
  );
}
