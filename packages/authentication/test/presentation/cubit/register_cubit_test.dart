import 'dart:io';

import 'package:authentication/authentication.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared/shared.dart';

class _MockFormInputRepository extends Mock implements FormInputRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockCompleteRegistrationUseCase extends Mock
    implements CompleteRegistrationUseCase {}

class _MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

void main() {
  late _MockFormInputRepository formInputRepository;
  late _MockAuthRepository authRepository;
  late _MockCompleteRegistrationUseCase completeRegistrationUseCase;
  late _MockAuthCubit authCubit;

  const nikField = FormInputField(
    label: 'nik',
    display: 'NIK',
    type: 'text',
    validate: true,
    readOnly: false,
  );

  RegisterCubit build() => RegisterCubit(
    formInputRepository,
    authRepository,
    completeRegistrationUseCase,
    authCubit,
  );

  setUpAll(() {
    registerFallbackValue(
      const CompleteRegistrationParams(
        forms: [],
        formResults: {},
        selfieImageBytes: [],
      ),
    );
    registerFallbackValue(const User(id: '', email: '', role: ''));
  });

  setUp(() {
    formInputRepository = _MockFormInputRepository();
    authRepository = _MockAuthRepository();
    completeRegistrationUseCase = _MockCompleteRegistrationUseCase();
    authCubit = _MockAuthCubit();
    when(
      () => authCubit.setAuthenticated(
        any(),
        sessionProfile: any(named: 'sessionProfile'),
      ),
    ).thenReturn(null);
  });

  blocTest<RegisterCubit, RegisterState>(
    'setSelfiePath moves to selfieTaken with the given path',
    build: build,
    act: (cubit) => cubit.setSelfiePath('/tmp/selfie.jpg'),
    expect: () => [
      const RegisterState(
        status: RegisterStatus.selfieTaken,
        selfiePath: '/tmp/selfie.jpg',
      ),
    ],
  );

  blocTest<RegisterCubit, RegisterState>(
    'retakeSelfie goes back to takingSelfie and clears the path',
    build: build,
    seed: () => const RegisterState(
      status: RegisterStatus.selfieTaken,
      selfiePath: '/tmp/selfie.jpg',
    ),
    act: (cubit) => cubit.retakeSelfie(),
    expect: () => [const RegisterState()],
  );

  blocTest<RegisterCubit, RegisterState>(
    'loadForm emits [loadingForm, inputForm] with the fetched schema on success',
    build: () {
      when(
        () => formInputRepository.getForm('/registrasi/profile'),
      ).thenAnswer((_) async => const Ok([nikField]));
      return build();
    },
    act: (cubit) => cubit.loadForm(),
    expect: () => [
      const RegisterState(status: RegisterStatus.loadingForm),
      const RegisterState(status: RegisterStatus.inputForm, forms: [nikField]),
    ],
  );

  blocTest<RegisterCubit, RegisterState>(
    'loadForm emits [loadingForm, failed] when the fetch fails',
    build: () {
      when(
        () => formInputRepository.getForm('/registrasi/profile'),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      return build();
    },
    act: (cubit) => cubit.loadForm(),
    expect: () => [
      const RegisterState(status: RegisterStatus.loadingForm),
      const RegisterState(
        status: RegisterStatus.failed,
        error: NetworkFailure(),
      ),
    ],
  );

  blocTest<RegisterCubit, RegisterState>(
    'setInput stores the value under the field label',
    build: build,
    seed: () => const RegisterState(
      status: RegisterStatus.inputForm,
      forms: [nikField],
    ),
    act: (cubit) => cubit.setInput('nik', '1234567890123456'),
    expect: () => [
      const RegisterState(
        status: RegisterStatus.inputForm,
        forms: [nikField],
        formResults: {'nik': '1234567890123456'},
      ),
    ],
  );

  group('RegisterCubit.submit', () {
    blocTest<RegisterCubit, RegisterState>(
      'emits failed immediately, without calling the use case, when there '
      'is no selfie path',
      build: build,
      seed: () => const RegisterState(
        status: RegisterStatus.inputForm,
        forms: [nikField],
      ),
      act: (cubit) => cubit.submit(),
      expect: () => [
        const RegisterState(
          status: RegisterStatus.failed,
          forms: [nikField],
          error: ValidationFailure('Foto selfie tidak ditemukan.'),
        ),
      ],
      verify: (_) {
        verifyNever(() => completeRegistrationUseCase(any()));
      },
    );

    blocTest<RegisterCubit, RegisterState>(
      'on success: deletes the local selfie file, refreshes the '
      'isRegistered flag through AuthCubit, and emits success — proven '
      'against a real temp file rather than asserted from a comment, same '
      "class of proof as PaymentCubit's proof-image cleanup test",
      setUp: () {
        when(
          () => completeRegistrationUseCase(any()),
        ).thenAnswer((_) async => const Ok(null));
        when(() => authRepository.refreshProfile()).thenAnswer(
          (_) async => const Ok((
            User(
              id: '1',
              email: 'a@example.com',
              role: 'admin',
              isRegistered: true,
            ),
            SessionProfile(avatar: '', name: 'Ani', nik: '1234567890123456'),
          )),
        );
      },
      build: build,
      seed: () {
        final file = File(
          '${Directory.systemTemp.path}/register_cubit_test_selfie.jpg',
        )..writeAsBytesSync([1, 2, 3]);
        return RegisterState(
          status: RegisterStatus.inputForm,
          forms: const [nikField],
          formResults: const {'nik': '1234567890123456'},
          selfiePath: file.path,
        );
      },
      act: (cubit) => cubit.submit(),
      verify: (cubit) async {
        final file = File(
          '${Directory.systemTemp.path}/register_cubit_test_selfie.jpg',
        );
        expect(await file.exists(), isFalse);
        expect(cubit.state.status, RegisterStatus.success);
        verify(
          () => authCubit.setAuthenticated(
            any(that: isA<User>()),
            sessionProfile: any(named: 'sessionProfile'),
          ),
        ).called(1);
      },
    );

    blocTest<RegisterCubit, RegisterState>(
      'on failure: goes back to inputForm carrying the failure, and never '
      'touches the selfie file or AuthCubit',
      setUp: () {
        when(() => completeRegistrationUseCase(any())).thenAnswer(
          (_) async => const Err(ValidationFailure('NIK masih kosong.')),
        );
      },
      build: build,
      seed: () {
        final file = File(
          '${Directory.systemTemp.path}/register_cubit_test_selfie_2.jpg',
        )..writeAsBytesSync([1, 2, 3]);
        return RegisterState(
          status: RegisterStatus.inputForm,
          forms: const [nikField],
          selfiePath: file.path,
        );
      },
      act: (cubit) => cubit.submit(),
      verify: (cubit) async {
        final file = File(
          '${Directory.systemTemp.path}/register_cubit_test_selfie_2.jpg',
        );
        expect(await file.exists(), isTrue);
        await file.delete();
        expect(cubit.state.status, RegisterStatus.inputForm);
        expect(cubit.state.error, const ValidationFailure('NIK masih kosong.'));
        verifyNever(() => authRepository.refreshProfile());
        verifyNever(
          () => authCubit.setAuthenticated(
            any(),
            sessionProfile: any(named: 'sessionProfile'),
          ),
        );
      },
    );
  });
}
