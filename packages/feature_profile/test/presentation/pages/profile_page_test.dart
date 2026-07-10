import 'package:authentication/authentication.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:feature_profile/src/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

void main() {
  late _MockAuthCubit authCubit;

  Widget harness(_MockAuthCubit authCubit) {
    return MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => BlocProvider<AuthCubit>.value(
              value: authCubit,
              child: const ProfileView(),
            ),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) =>
                const Scaffold(body: Text('login-page')),
          ),
        ],
      ),
    );
  }

  setUp(() {
    authCubit = _MockAuthCubit();
    when(() => authCubit.logout()).thenAnswer((_) async {});
  });

  const sessionProfile = SessionProfile(
    avatar: '',
    name: 'Ani',
    nik: '1234567890123456',
  );
  const user = User(id: '1', email: 'a@example.com', role: 'user');

  testWidgets('shows avatar/name/nik read-only, no editable field', (
    tester,
  ) async {
    when(() => authCubit.state).thenReturn(
      const AuthState.authenticated(user, sessionProfile: sessionProfile),
    );

    await tester.pumpWidget(harness(authCubit));

    expect(find.text('Ani'), findsOneWidget);
    expect(find.text('1234567890123456'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    // Read-only: the old app's real account_page has zero TextFields.
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
    'shows a fallback message when authenticated with no session profile '
    'yet (e.g. the synthetic email/password login flow)',
    (tester) async {
      when(
        () => authCubit.state,
      ).thenReturn(const AuthState.authenticated(user));

      await tester.pumpWidget(harness(authCubit));

      expect(
        find.text('Belum ada data akun untuk ditampilkan.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('tapping Logout shows a confirmation dialog first', (
    tester,
  ) async {
    when(() => authCubit.state).thenReturn(
      const AuthState.authenticated(user, sessionProfile: sessionProfile),
    );

    await tester.pumpWidget(harness(authCubit));
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Apakah kamu yakin untuk keluar? Kamu harus login lagi untuk '
        'menggunakan aplikasi.',
      ),
      findsOneWidget,
    );
    verifyNever(() => authCubit.logout());
  });

  testWidgets('confirming the dialog logs out and navigates to /login', (
    tester,
  ) async {
    when(() => authCubit.state).thenReturn(
      const AuthState.authenticated(user, sessionProfile: sessionProfile),
    );

    await tester.pumpWidget(harness(authCubit));
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logout').last);
    await tester.pumpAndSettle();

    verify(() => authCubit.logout()).called(1);
    expect(find.text('login-page'), findsOneWidget);
  });

  testWidgets('cancelling the dialog never logs out', (tester) async {
    when(() => authCubit.state).thenReturn(
      const AuthState.authenticated(user, sessionProfile: sessionProfile),
    );

    await tester.pumpWidget(harness(authCubit));
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    verifyNever(() => authCubit.logout());
    expect(find.text('Ani'), findsOneWidget);
  });
}
