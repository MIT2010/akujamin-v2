import 'package:authentication/authentication.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoginUseCase extends Mock implements LoginUseCase {}

class _MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

void main() {
  late _MockLoginUseCase loginUseCase;
  late _MockAuthCubit authCubit;

  setUpAll(() {
    registerFallbackValue(const LoginParams(email: '', password: ''));
    registerFallbackValue(const User(id: '', email: '', role: ''));
  });

  setUp(() {
    loginUseCase = _MockLoginUseCase();
    authCubit = _MockAuthCubit();
    when(() => authCubit.setAuthenticated(any())).thenReturn(null);
  });

  const user = User(id: '1', email: 'a@example.com', role: 'admin');

  blocTest<LoginCubit, LoginState>(
    'emits [loading, success] when the use case succeeds, and tells '
    'AuthCubit about the new session',
    build: () {
      when(() => loginUseCase(any())).thenAnswer((_) async => const Ok(user));
      return LoginCubit(loginUseCase, authCubit);
    },
    act: (cubit) => cubit.submit(email: 'a@example.com', password: 'secret'),
    expect: () => [const LoginState.loading(), LoginState.success(user)],
    verify: (_) {
      verify(() => authCubit.setAuthenticated(user)).called(1);
    },
  );

  blocTest<LoginCubit, LoginState>(
    'emits [loading, failure] when the use case fails, and never touches '
    'AuthCubit',
    build: () {
      when(
        () => loginUseCase(any()),
      ).thenAnswer((_) async => const Err(UnauthorizedFailure()));
      return LoginCubit(loginUseCase, authCubit);
    },
    act: (cubit) => cubit.submit(email: 'a@example.com', password: 'wrong'),
    expect: () => [
      const LoginState.loading(),
      const LoginState.failure(UnauthorizedFailure()),
    ],
    verify: (_) {
      verifyNever(() => authCubit.setAuthenticated(any()));
    },
  );
}
