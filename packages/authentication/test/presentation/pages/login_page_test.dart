import 'package:authentication/src/domain/entities/user.dart';
import 'package:authentication/src/presentation/cubit/login_cubit.dart';
import 'package:authentication/src/presentation/cubit/login_state.dart';
import 'package:authentication/src/presentation/pages/login_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoginCubit extends MockCubit<LoginState> implements LoginCubit {}

void main() {
  late _MockLoginCubit cubit;

  Widget harness(_MockLoginCubit cubit) {
    return MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, state) => BlocProvider<LoginCubit>.value(
              value: cubit,
              child: const LoginView(),
            ),
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) =>
                const Scaffold(body: Text('home-page')),
          ),
        ],
      ),
    );
  }

  setUp(() {
    cubit = _MockLoginCubit();
    when(() => cubit.state).thenReturn(const LoginState.initial());
    when(
      () => cubit.submit(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});
  });

  testWidgets('shows the email/password fields and a login button', (
    tester,
  ) async {
    whenListen(
      cubit,
      const Stream<LoginState>.empty(),
      initialState: const LoginState.initial(),
    );

    await tester.pumpWidget(harness(cubit));

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('shows a link to the OTP login flow', (tester) async {
    whenListen(
      cubit,
      const Stream<LoginState>.empty(),
      initialState: const LoginState.initial(),
    );

    await tester.pumpWidget(harness(cubit));

    // Not tapped here: tapping pushes OtpLoginPage, which resolves
    // OtpLoginCubit via get_it — out of scope for this bare harness (no
    // configureDependencies). Covered by otp_login_page_test.dart instead.
    expect(find.text('Masuk dengan nomor telepon'), findsOneWidget);
  });

  testWidgets('tapping login submits the entered credentials', (tester) async {
    whenListen(
      cubit,
      const Stream<LoginState>.empty(),
      initialState: const LoginState.initial(),
    );

    await tester.pumpWidget(harness(cubit));

    await tester.enterText(find.byType(TextField).at(0), 'a@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.text('Login'));

    verify(
      () => cubit.submit(email: 'a@example.com', password: 'secret'),
    ).called(1);
  });

  testWidgets('navigates to /home when the cubit emits success', (
    tester,
  ) async {
    const user = User(id: '1', email: 'a@example.com', role: 'admin');
    whenListen(
      cubit,
      Stream.fromIterable([LoginState.success(user)]),
      initialState: const LoginState.initial(),
    );

    await tester.pumpWidget(harness(cubit));
    await tester.pumpAndSettle();

    expect(find.text('home-page'), findsOneWidget);
  });

  testWidgets('shows a snackbar with the failure message on failure', (
    tester,
  ) async {
    whenListen(
      cubit,
      Stream.fromIterable([const LoginState.failure(UnauthorizedFailure())]),
      initialState: const LoginState.initial(),
    );

    await tester.pumpWidget(harness(cubit));
    await tester.pumpAndSettle();

    expect(find.text('Session expired'), findsOneWidget);
  });
}
