import 'package:authentication/authentication.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSendOtpUseCase extends Mock implements SendOtpUseCase {}

class _MockVerifyOtpUseCase extends Mock implements VerifyOtpUseCase {}

class _MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

void main() {
  late _MockSendOtpUseCase sendOtpUseCase;
  late _MockVerifyOtpUseCase verifyOtpUseCase;
  late _MockAuthCubit authCubit;

  final expiresAt = DateTime.parse('2026-07-10T12:00:00.000Z');
  const user = User(id: '1', email: 'a@example.com', role: 'admin');

  setUpAll(() {
    registerFallbackValue(const SendOtpParams(phoneNumber: ''));
    registerFallbackValue(const VerifyOtpParams(phoneNumber: '', otpCode: ''));
    registerFallbackValue(const User(id: '', email: '', role: ''));
  });

  setUp(() {
    sendOtpUseCase = _MockSendOtpUseCase();
    verifyOtpUseCase = _MockVerifyOtpUseCase();
    authCubit = _MockAuthCubit();
    when(() => authCubit.setAuthenticated(any())).thenReturn(null);
  });

  blocTest<OtpLoginCubit, OtpLoginState>(
    'emits [sendingOtp, otpEntry] when sendOtp succeeds',
    build: () {
      when(() => sendOtpUseCase(any())).thenAnswer((_) async => Ok(expiresAt));
      return OtpLoginCubit(sendOtpUseCase, verifyOtpUseCase, authCubit);
    },
    act: (cubit) => cubit.sendOtp('81234567890'),
    expect: () => [
      const OtpLoginState.sendingOtp(),
      OtpLoginState.otpEntry(phoneNumber: '81234567890', expiresAt: expiresAt),
    ],
  );

  blocTest<OtpLoginCubit, OtpLoginState>(
    'emits [sendingOtp, sendOtpFailure] when sendOtp fails',
    build: () {
      when(
        () => sendOtpUseCase(any()),
      ).thenAnswer((_) async => const Err(ValidationFailure('bad phone')));
      return OtpLoginCubit(sendOtpUseCase, verifyOtpUseCase, authCubit);
    },
    act: (cubit) => cubit.sendOtp(''),
    expect: () => [
      const OtpLoginState.sendingOtp(),
      const OtpLoginState.sendOtpFailure(ValidationFailure('bad phone')),
    ],
  );

  blocTest<OtpLoginCubit, OtpLoginState>(
    'emits [verifyingOtp, success] when verifyOtp succeeds, and tells '
    'AuthCubit about the new session',
    build: () {
      when(
        () => verifyOtpUseCase(any()),
      ).thenAnswer((_) async => const Ok(user));
      return OtpLoginCubit(sendOtpUseCase, verifyOtpUseCase, authCubit);
    },
    act: (cubit) => cubit.verifyOtp(
      phoneNumber: '81234567890',
      otpCode: '123456',
      expiresAt: expiresAt,
    ),
    expect: () => [
      OtpLoginState.verifyingOtp(
        phoneNumber: '81234567890',
        expiresAt: expiresAt,
      ),
      OtpLoginState.success(user),
    ],
    verify: (_) {
      verify(() => authCubit.setAuthenticated(user)).called(1);
    },
  );

  blocTest<OtpLoginCubit, OtpLoginState>(
    'emits [verifyingOtp, verifyOtpFailure] when verifyOtp fails, and '
    'never touches AuthCubit',
    build: () {
      when(
        () => verifyOtpUseCase(any()),
      ).thenAnswer((_) async => const Err(UnauthorizedFailure()));
      return OtpLoginCubit(sendOtpUseCase, verifyOtpUseCase, authCubit);
    },
    act: (cubit) => cubit.verifyOtp(
      phoneNumber: '81234567890',
      otpCode: 'wrong',
      expiresAt: expiresAt,
    ),
    expect: () => [
      OtpLoginState.verifyingOtp(
        phoneNumber: '81234567890',
        expiresAt: expiresAt,
      ),
      OtpLoginState.verifyOtpFailure(
        failure: const UnauthorizedFailure(),
        phoneNumber: '81234567890',
        expiresAt: expiresAt,
      ),
    ],
    verify: (_) {
      verifyNever(() => authCubit.setAuthenticated(any()));
    },
  );

  blocTest<OtpLoginCubit, OtpLoginState>(
    'backToPhoneEntry resets to phoneEntry',
    build: () => OtpLoginCubit(sendOtpUseCase, verifyOtpUseCase, authCubit),
    seed: () => OtpLoginState.otpEntry(
      phoneNumber: '81234567890',
      expiresAt: expiresAt,
    ),
    act: (cubit) => cubit.backToPhoneEntry(),
    expect: () => [const OtpLoginState.phoneEntry()],
  );
}
