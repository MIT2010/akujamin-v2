import 'package:authentication/authentication.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared/shared.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;
  late CompleteRegistrationUseCase useCase;

  setUpAll(() {
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    repository = _MockAuthRepository();
    useCase = CompleteRegistrationUseCase(repository);
  });

  const nameField = FormInputField(
    label: 'nama',
    display: 'Nama',
    type: 'text',
    validate: true,
    readOnly: false,
  );
  const nikField = FormInputField(
    label: 'nik',
    display: 'NIK',
    type: 'text',
    validate: true,
    readOnly: false,
  );

  test('delegates to the repository and returns Ok when every field is '
      'present and the NIK is 16 digits', () async {
    when(
      () => repository.submitRegistration(
        formData: any(named: 'formData'),
        selfieImageBytes: any(named: 'selfieImageBytes'),
      ),
    ).thenAnswer((_) async => const Ok(null));

    final result = await useCase(
      CompleteRegistrationParams(
        forms: const [nameField, nikField],
        formResults: const {'nama': 'Ani', 'nik': '1234567890123456'},
        selfieImageBytes: const [1, 2, 3],
      ),
    );

    expect(result.isOk, isTrue);
    verify(
      () => repository.submitRegistration(
        formData: {'nama': 'Ani', 'nik': '1234567890123456'},
        selfieImageBytes: [1, 2, 3],
      ),
    ).called(1);
  });

  test('returns a ValidationFailure without calling the repository when a '
      'schema field is missing from formResults', () async {
    final result = await useCase(
      CompleteRegistrationParams(
        forms: const [nameField, nikField],
        formResults: const {'nama': 'Ani'},
        selfieImageBytes: const [1, 2, 3],
      ),
    );

    expect(result.isErr, isTrue);
    expect((result as Err<Failure, void>).failure, isA<ValidationFailure>());
    verifyNever(
      () => repository.submitRegistration(
        formData: any(named: 'formData'),
        selfieImageBytes: any(named: 'selfieImageBytes'),
      ),
    );
  });

  test('returns a ValidationFailure without calling the repository when the '
      'NIK is not exactly 16 digits', () async {
    final result = await useCase(
      CompleteRegistrationParams(
        forms: const [nikField],
        formResults: const {'nik': '123'},
        selfieImageBytes: const [1, 2, 3],
      ),
    );

    expect(result.isErr, isTrue);
    expect((result as Err<Failure, void>).failure, isA<ValidationFailure>());
    verifyNever(
      () => repository.submitRegistration(
        formData: any(named: 'formData'),
        selfieImageBytes: any(named: 'selfieImageBytes'),
      ),
    );
  });

  test('approved fix: a schema with no nik field never crashes on '
      "formResults['nik'].length -- the null check happens before the "
      'length is read, unlike the old app which read the length '
      'unconditionally', () async {
    when(
      () => repository.submitRegistration(
        formData: any(named: 'formData'),
        selfieImageBytes: any(named: 'selfieImageBytes'),
      ),
    ).thenAnswer((_) async => const Ok(null));

    final result = await useCase(
      CompleteRegistrationParams(
        forms: const [nameField],
        formResults: const {'nama': 'Ani'},
        selfieImageBytes: const [1, 2, 3],
      ),
    );

    expect(result.isOk, isTrue);
  });
}
