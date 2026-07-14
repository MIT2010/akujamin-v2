import 'package:authentication/authentication.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:feature_home/feature_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

void main() {
  late _MockAuthCubit authCubit;

  const registeredUser = User(
    id: '1',
    email: 'a@example.com',
    role: 'peserta',
    isRegistered: true,
  );
  const unregisteredUser = User(
    id: '1',
    email: 'a@example.com',
    role: 'peserta',
  );
  // avatar deliberately '' (not a real URL) — a NetworkImage fetch under
  // flutter_test always fails (HTTP is stubbed to return 400), same reason
  // feature_profile's own widget test uses an empty avatar throughout.
  const profile = SessionProfile(
    avatar: '',
    name: 'Ani',
    nik: '1234567890123456',
  );

  Widget harness() {
    return BlocProvider<AuthCubit>.value(
      value: authCubit,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/home',
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeView(),
            ),
            GoRoute(
              path: '/register',
              builder: (context, state) =>
                  const Scaffold(body: Text('register-page')),
            ),
          ],
        ),
      ),
    );
  }

  setUp(() {
    authCubit = _MockAuthCubit();
    when(() => authCubit.logout()).thenAnswer((_) async {});
  });

  group('HomeView — profile teaser', () {
    testWidgets('shows the SessionProfile name and avatar when one exists', (
      tester,
    ) async {
      when(() => authCubit.state).thenReturn(
        const AuthState.authenticated(registeredUser, sessionProfile: profile),
      );

      await tester.pumpWidget(harness());

      expect(find.text('Halo, Ani'), findsOneWidget);
      expect(find.text('a@example.com'), findsOneWidget);
    });

    testWidgets(
      'falls back to the account email when there is no SessionProfile — '
      'the email/password LoginCubit flow never populates one',
      (tester) async {
        when(
          () => authCubit.state,
        ).thenReturn(const AuthState.authenticated(registeredUser));

        await tester.pumpWidget(harness());

        expect(find.text('Halo, a@example.com'), findsOneWidget);
      },
    );
  });

  group('HomeView — incomplete-profile banner', () {
    testWidgets('shown when the user is not registered', (tester) async {
      when(
        () => authCubit.state,
      ).thenReturn(const AuthState.authenticated(unregisteredUser));

      await tester.pumpWidget(harness());

      expect(find.textContaining('Lengkapi profil kamu'), findsOneWidget);
    });

    testWidgets('hidden when the user is already registered', (tester) async {
      when(
        () => authCubit.state,
      ).thenReturn(const AuthState.authenticated(registeredUser));

      await tester.pumpWidget(harness());

      expect(find.textContaining('Lengkapi profil kamu'), findsNothing);
    });

    testWidgets('tapping the banner navigates to /register', (tester) async {
      when(
        () => authCubit.state,
      ).thenReturn(const AuthState.authenticated(unregisteredUser));

      await tester.pumpWidget(harness());
      await tester.tap(find.textContaining('Lengkapi profil kamu'));
      await tester.pumpAndSettle();

      expect(find.text('register-page'), findsOneWidget);
    });
  });

  group('HomeView AppBar — Riwayat/Akun no longer live here (TAHAP 3, '
      'MIGRATION_LOG.md dashboard-shell finding): apps/mobile\'s bottom-nav '
      'shell reaches /history and /profile now, so these AppBar icons would '
      'be a live duplicate of the shell tabs', () {
    testWidgets('the history and person AppBar buttons are gone (the profile '
        "teaser's own avatar-fallback icon also happens to be Icons.person, "
        'so this checks specifically for an IconButton, not just any icon '
        'anywhere on screen)', (tester) async {
      when(
        () => authCubit.state,
      ).thenReturn(const AuthState.authenticated(registeredUser));

      await tester.pumpWidget(harness());

      expect(find.byIcon(Icons.history), findsNothing);
      expect(find.widgetWithIcon(IconButton, Icons.person), findsNothing);
    });

    testWidgets(
      'the remaining AppBar actions (onboarding/FAQ/counseling/payment/'
      'logout) are still there — the removal was scoped to exactly the '
      'two duplicated icons, not the whole AppBar',
      (tester) async {
        when(
          () => authCubit.state,
        ).thenReturn(const AuthState.authenticated(registeredUser));

        await tester.pumpWidget(harness());

        expect(find.byIcon(Icons.info_outline), findsOneWidget);
        expect(find.byIcon(Icons.help_outline), findsOneWidget);
        expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
        expect(find.byIcon(Icons.payment_outlined), findsOneWidget);
        expect(find.byIcon(Icons.logout), findsOneWidget);
      },
    );
  });

  testWidgets('tapping logout calls AuthCubit.logout() and returns to /login', (
    tester,
  ) async {
    when(
      () => authCubit.state,
    ).thenReturn(const AuthState.authenticated(registeredUser));

    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: authCubit,
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/home',
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeView(),
              ),
              GoRoute(
                path: '/login',
                builder: (context, state) =>
                    const Scaffold(body: Text('login-page')),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    verify(() => authCubit.logout()).called(1);
    expect(find.text('login-page'), findsOneWidget);
  });
}
