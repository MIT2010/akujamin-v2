import 'package:authentication/authentication.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;
  late SendOtpUseCase useCase;

  setUp(() {
    repository = _MockAuthRepository();
    useCase = SendOtpUseCase(repository);
  });

  test(
    'prefixes the phone number with 62 and delegates to the repository',
    () async {
      final expiresAt = DateTime.parse('2026-07-10T12:00:00.000Z');
      when(
        () => repository.sendOtp(phoneNumber: '6281234567890'),
      ).thenAnswer((_) async => Ok(expiresAt));

      final result = await useCase(
        const SendOtpParams(phoneNumber: '81234567890'),
      );

      expect(result.isOk, isTrue);
      verify(() => repository.sendOtp(phoneNumber: '6281234567890')).called(1);
    },
  );

  test('strips a leading 0 before prefixing with 62 -- real bug, found '
      '2026-07-16: typing a phone number the normal Indonesian way '
      '(leading 0) used to produce a malformed 62081234567890', () async {
    final expiresAt = DateTime.parse('2026-07-10T12:00:00.000Z');
    when(
      () => repository.sendOtp(phoneNumber: '6281234567890'),
    ).thenAnswer((_) async => Ok(expiresAt));

    final result = await useCase(
      const SendOtpParams(phoneNumber: '081234567890'),
    );

    expect(result.isOk, isTrue);
    verify(() => repository.sendOtp(phoneNumber: '6281234567890')).called(1);
  });

  test(
    'leaves a phone number that already has the 62 country code untouched',
    () async {
      final expiresAt = DateTime.parse('2026-07-10T12:00:00.000Z');
      when(
        () => repository.sendOtp(phoneNumber: '6281234567890'),
      ).thenAnswer((_) async => Ok(expiresAt));

      final result = await useCase(
        const SendOtpParams(phoneNumber: '6281234567890'),
      );

      expect(result.isOk, isTrue);
      verify(() => repository.sendOtp(phoneNumber: '6281234567890')).called(1);
    },
  );

  test(
    'returns a ValidationFailure without calling the repository when the phone is empty',
    () async {
      final result = await useCase(const SendOtpParams(phoneNumber: ''));

      expect(result.isErr, isTrue);
      expect(
        (result as Err<Failure, DateTime>).failure,
        isA<ValidationFailure>(),
      );
      verifyNever(
        () => repository.sendOtp(phoneNumber: any(named: 'phoneNumber')),
      );
    },
  );

  test(
    'returns a ValidationFailure without calling the repository when the phone is too short',
    () async {
      final result = await useCase(const SendOtpParams(phoneNumber: '1234'));

      expect(result.isErr, isTrue);
      expect(
        (result as Err<Failure, DateTime>).failure,
        isA<ValidationFailure>(),
      );
      verifyNever(
        () => repository.sendOtp(phoneNumber: any(named: 'phoneNumber')),
      );
    },
  );
}
