import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

class _FakeAuthSession implements AuthSession {
  _FakeAuthSession(this._status);
  final AuthSessionStatus _status;

  @override
  AuthSessionStatus get status => _status;

  @override
  Stream<AuthSessionStatus> get statusStream => Stream.value(_status);
}

/// Unlike [_FakeAuthSession] above (fixed status, single-value stream), this
/// one can actually flip mid-test — the shape `AuthSessionAdapter`
/// (`authentication`) has in production, where `status`/`statusStream`
/// follow a live `AuthCubit` through a real login/logout, not a value fixed
/// for the test's lifetime.
class _StreamingFakeAuthSession implements AuthSession {
  final _controller = StreamController<AuthSessionStatus>.broadcast();
  AuthSessionStatus _status = AuthSessionStatus.unauthenticated;

  @override
  AuthSessionStatus get status => _status;

  @override
  Stream<AuthSessionStatus> get statusStream => _controller.stream;

  void setStatus(AuthSessionStatus status) {
    _status = status;
    _controller.add(status);
  }
}

final _standaloneRoutes = <RouteBase>[
  GoRoute(
    path: '/',
    builder: (context, state) => const Scaffold(body: Text('root-page')),
  ),
  GoRoute(
    path: '/login',
    builder: (context, state) => const Scaffold(body: Text('login-page')),
  ),
  GoRoute(
    path: '/home',
    builder: (context, state) => const Scaffold(body: Text('home-page')),
  ),
];

/// The real shape `apps/mobile/lib/src/app.dart` actually registers — no
/// route for `/` at all. `AppRouter` is never given an explicit
/// `initialLocation`, so `GoRouter` defaults to `/` on cold start; this
/// fixture is what exposes the bug the fixture above (which happens to
/// register a `/` route) can't catch.
final _standaloneRoutesWithoutRoot = <RouteBase>[
  GoRoute(
    path: '/login',
    builder: (context, state) => const Scaffold(body: Text('login-page')),
  ),
  GoRoute(
    path: '/home',
    builder: (context, state) => const Scaffold(body: Text('home-page')),
  ),
];

final _roleGuardedRoutes = <RouteBase>[
  GoRoute(
    path: '/home',
    builder: (context, state) => const Scaffold(body: Text('home-page')),
  ),
  AppRoute(
    path: '/admin',
    roles: const ['admin'],
    builder: (context, state) => const Scaffold(body: Text('admin-page')),
  ),
];

final _shellDestinations = const [
  AppShellDestination(path: '/home', icon: Icons.home, label: 'Home'),
  AppShellDestination(path: '/profile', icon: Icons.person, label: 'Profile'),
];

final _shellRoutes = <RouteBase>[
  GoRoute(path: '/home', builder: (context, state) => const Text('home-tab')),
  GoRoute(
    path: '/profile',
    builder: (context, state) => const Text('profile-tab'),
  ),
];

void main() {
  group('AppRouter redirect', () {
    testWidgets('redirects an unauthenticated user to /login', (tester) async {
      final appRouter = AppRouter(
        _FakeAuthSession(AuthSessionStatus.unauthenticated),
      )..standaloneRoutes = _standaloneRoutes;

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: appRouter.router),
      );
      await tester.pumpAndSettle();

      expect(find.text('login-page'), findsOneWidget);
    });

    testWidgets(
      'does not redirect an authenticated user off the requested route',
      (tester) async {
        final appRouter = AppRouter(
          _FakeAuthSession(const AuthSessionStatus(isAuthenticated: true)),
        )..standaloneRoutes = _standaloneRoutes;

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: appRouter.router),
        );
        await tester.pumpAndSettle();

        expect(find.text('root-page'), findsOneWidget);
      },
    );

    testWidgets('redirects an authenticated user away from /login', (
      tester,
    ) async {
      final appRouter = AppRouter(
        _FakeAuthSession(const AuthSessionStatus(isAuthenticated: true)),
      )..standaloneRoutes = _standaloneRoutes;

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: appRouter.router),
      );
      appRouter.router.go('/login');
      await tester.pumpAndSettle();

      expect(find.text('home-page'), findsOneWidget);
      expect(find.text('login-page'), findsNothing);
    });

    testWidgets('falls back to NotFoundPage for an unmatched route', (
      tester,
    ) async {
      final appRouter = AppRouter(
        _FakeAuthSession(const AuthSessionStatus(isAuthenticated: true)),
      )..standaloneRoutes = _standaloneRoutes;

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: appRouter.router),
      );
      appRouter.router.go('/nowhere');
      await tester.pumpAndSettle();

      expect(find.text('Page not found'), findsOneWidget);
    });

    testWidgets(
      'sends an authenticated user to /home when landing on the default '
      'initialLocation (/) and no route registers it — the exact situation '
      'on every cold start once a session is restored from disk, since '
      'apps/mobile never gives AppRouter an explicit initialLocation and '
      'never registers a GoRoute for "/" itself',
      (tester) async {
        final appRouter = AppRouter(
          _FakeAuthSession(const AuthSessionStatus(isAuthenticated: true)),
        )..standaloneRoutes = _standaloneRoutesWithoutRoot;

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: appRouter.router),
        );
        await tester.pumpAndSettle();

        expect(find.text('home-page'), findsOneWidget);
        expect(find.text('Page not found'), findsNothing);
      },
    );

    testWidgets(
      'still falls back to NotFoundPage for a genuinely unmatched route '
      'that is not "/" — the fix above must not swallow real 404s',
      (tester) async {
        final appRouter = AppRouter(
          _FakeAuthSession(const AuthSessionStatus(isAuthenticated: true)),
        )..standaloneRoutes = _standaloneRoutesWithoutRoot;

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: appRouter.router),
        );
        appRouter.router.go('/nowhere');
        await tester.pumpAndSettle();

        expect(find.text('Page not found'), findsOneWidget);
      },
    );
  });

  group('AppRouter role guard', () {
    testWidgets(
      'redirects away from a role-guarded route when the user lacks the role',
      (tester) async {
        final appRouter = AppRouter(
          _FakeAuthSession(
            const AuthSessionStatus(isAuthenticated: true, roles: ['user']),
          ),
        )..standaloneRoutes = _roleGuardedRoutes;

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: appRouter.router),
        );
        appRouter.router.go('/admin');
        await tester.pumpAndSettle();

        expect(find.text('home-page'), findsOneWidget);
        expect(find.text('admin-page'), findsNothing);
      },
    );

    testWidgets('allows a role-guarded route when the user has the role', (
      tester,
    ) async {
      final appRouter = AppRouter(
        _FakeAuthSession(
          const AuthSessionStatus(isAuthenticated: true, roles: ['admin']),
        ),
      )..standaloneRoutes = _roleGuardedRoutes;

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: appRouter.router),
      );
      appRouter.router.go('/admin');
      await tester.pumpAndSettle();

      expect(find.text('admin-page'), findsOneWidget);
    });
  });

  group('AppRouter shell (persistent bottom nav)', () {
    testWidgets('shows a bottom nav bar with the given shell destinations', (
      tester,
    ) async {
      final appRouter =
          AppRouter(
              _FakeAuthSession(const AuthSessionStatus(isAuthenticated: true)),
            )
            ..standaloneRoutes = [
              GoRoute(
                path: '/login',
                builder: (context, state) =>
                    const Scaffold(body: Text('login-page')),
              ),
            ]
            ..shellDestinations = _shellDestinations
            ..shellRoutes = _shellRoutes;

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: appRouter.router),
      );
      appRouter.router.go('/home');
      await tester.pumpAndSettle();

      expect(find.text('home-tab'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('switches tabs when a destination is tapped', (tester) async {
      final appRouter =
          AppRouter(
              _FakeAuthSession(const AuthSessionStatus(isAuthenticated: true)),
            )
            ..standaloneRoutes = [
              GoRoute(
                path: '/login',
                builder: (context, state) =>
                    const Scaffold(body: Text('login-page')),
              ),
            ]
            ..shellDestinations = _shellDestinations
            ..shellRoutes = _shellRoutes;

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: appRouter.router),
      );
      appRouter.router.go('/home');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.text('profile-tab'), findsOneWidget);
      expect(find.text('home-tab'), findsNothing);
    });
  });

  group('AppRouter redirect — dynamic session changes', () {
    late _StreamingFakeAuthSession authSession;
    late AppRouter appRouter;

    setUp(() {
      authSession = _StreamingFakeAuthSession();
      appRouter = AppRouter(authSession)..standaloneRoutes = _standaloneRoutes;
    });

    testWidgets(
      'moves to /home once the session flips to authenticated — the exact '
      'transition AuthSessionAdapter drives after a real login',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp.router(routerConfig: appRouter.router),
        );
        await tester.pumpAndSettle();
        expect(find.text('login-page'), findsOneWidget);

        authSession.setStatus(
          const AuthSessionStatus(isAuthenticated: true, roles: ['admin']),
        );
        await tester.pumpAndSettle();

        // Landed on /login (redirected there while unauthenticated), so
        // once authenticated the "bounce off /login" rule sends it to
        // /home specifically — not just back to the original / location.
        expect(find.text('home-page'), findsOneWidget);
        expect(find.text('login-page'), findsNothing);
      },
    );

    testWidgets(
      'bounces back to /login once the session flips to unauthenticated — '
      'the exact transition AuthSessionAdapter drives after logout',
      (tester) async {
        authSession.setStatus(const AuthSessionStatus(isAuthenticated: true));
        await tester.pumpWidget(
          MaterialApp.router(routerConfig: appRouter.router),
        );
        appRouter.router.go('/home');
        await tester.pumpAndSettle();
        expect(find.text('home-page'), findsOneWidget);

        authSession.setStatus(AuthSessionStatus.unauthenticated);
        await tester.pumpAndSettle();

        expect(find.text('login-page'), findsOneWidget);
      },
    );
  });
}
