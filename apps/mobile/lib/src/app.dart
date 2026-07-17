import 'package:authentication/authentication.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_about/feature_about.dart';
import 'package:feature_counseling/feature_counseling.dart';
import 'package:feature_history/feature_history.dart';
import 'package:feature_home/feature_home.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:feature_payment/feature_payment.dart';
import 'package:feature_profile/feature_profile.dart';
import 'package:feature_test/feature_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import 'dashboard_notification_listener.dart';

/// The composition root's widget (§13, §17): wires `AppRouter` (from
/// `shared`) into `MaterialApp.router`, themed from `design_system`.
///
/// **Real fix, found during the reconciliation audit (2026-07-14), not a
/// port**: `AuthSessionAdapter._toStatus()` maps `AuthState.initial()` (the
/// gap between app start and `AuthCubit._restoreCachedSession()`
/// finishing) to `AuthSessionStatus.unauthenticated` — the same status as a
/// confirmed-logged-out user. Measured directly (a throwaway widget test
/// pre-seeding a real cached session): the very first frame `AppRouter`
/// builds genuinely renders `/login`'s form for an already-authenticated
/// returning user, before the redirect flips to `/home` a couple of frames
/// later once the restore resolves — not a blank gap, a flash of the wrong,
/// fully-populated screen. The old app had a dedicated `AuthStatus.
/// checkingSession`/`/splash` gate for exactly this window; this is the
/// minimal functional equivalent — a loading indicator held until the
/// first real `AuthState` (`authenticated` or `unauthenticated`) is known,
/// not the old app's full splash carousel/branding (never migrated, no
/// live gap once this is fixed — see GAPS.md).
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardNotificationListener(
      child: BlocBuilder<AuthCubit, AuthState>(
        bloc: getIt<AuthCubit>(),
        builder: (context, state) {
          // `AuthRefreshing` gets the exact same splash gate as
          // `AuthInitial` (cold-boot session restore) -- real bug, found
          // 2026-07-17 from live testing: a reactive token refresh
          // (`RefreshTokenInterceptor`) used to leave the app showing
          // whatever the current screen's own paused-request state
          // happened to render, with nothing telling the user a refresh
          // was in progress, and no protection against `AppRouter`
          // redirecting to `/login` mid-refresh (see
          // `AuthSessionAdapter._toStatus`, which reports `refreshing` as
          // authenticated for exactly that reason). `AppRouter.router` is
          // a `late final` on the `getIt<AppRouter>()` singleton, so the
          // underlying `GoRouter`/`Navigator` state this gate briefly
          // hides is preserved, not reset, once the state flips back to
          // `authenticated` on a successful refresh.
          if (state is AuthInitial || state is AuthRefreshing) {
            return MaterialApp(
              title: Env.current.appName,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              // Real bug, found 2026-07-16 during live web testing, and
              // root-caused by reading Flutter 3.44.4's own source
              // (widgets/app.dart, _WidgetsAppState._initialRouteName): on
              // web, WidgetsApp *deliberately* overrides `initialRoute`
              // with `PlatformDispatcher.defaultRouteName` whenever the
              // browser's current URL isn't "/", to support deep linking.
              // Since this app uses hash routing, a hard reload on
              // `#/login` makes "/login" the actual initial route this
              // bare Navigator-based MaterialApp is asked to resolve --
              // and since it only declares `home` for "/", that lookup
              // fails and throws a caught "Could not navigate to initial
              // route" FlutterError every time. Setting `initialRoute:
              // '/'` (the first fix attempted here) has no effect, since
              // WidgetsApp ignores it in exactly this situation -- verified
              // by re-testing after a genuine hard reload and seeing the
              // same warning fire again. The real fix: a catch-all
              // `onGenerateRoute` so *any* requested route name --
              // "/login", "/home", whatever the browser's URL happened to
              // be -- resolves to this same loading screen instead of
              // failing route-table lookup.
              onGenerateRoute: (settings) => MaterialPageRoute<void>(
                builder: (context) => const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
              ),
            );
          }

          final appRouter = getIt<AppRouter>()
            ..standaloneRoutes = _routes
            ..shellRoutes = _shellRoutes
            ..shellDestinations = _shellDestinations;

          // Wraps MaterialApp.router (not the other way around) so it
          // mounts once for the app's whole lifetime, not just while a
          // shell tab is visible — see DashboardNotificationListener's doc
          // comment for why that distinction matters.
          return MaterialApp.router(
            // Real gap, found 2026-07-17 from live testing: every
            // `flavors/*.json` already carries an `APP_NAME` (e.g.
            // "AKUJAMIN Dev"), but this was hardcoded to the starter
            // kit's own generic title instead of reading it -- see
            // `Env.appName`'s doc comment for the other (Android
            // home-screen label) half of this same gap.
            title: Env.current.appName,
            routerConfig: appRouter.router,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
          );
        },
      ),
    );
  }
}

/// Routes outside the persistent bottom nav — either reached before a
/// session exists (`/login`, `/register`), or pushed full-screen on top of
/// the shell from one of its tabs (e.g. `/certificate` from `/history`,
/// `/chat/:code` from `/counseling`) exactly as the old app's equivalent
/// screens were never part of `CustomBottomNavBar` either.
final _routes = <RouteBase>[
  GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
  // A real GoRoute, unlike OtpLoginPage's Navigator.push workaround —
  // AppRouter._redirect has no special case for '/register' the way it
  // does for '/login', so an authenticated user landing here just falls
  // through the normal `loggedIn` branch and renders normally.
  GoRoute(path: '/register', builder: (context, state) => const RegisterPage()),
  GoRoute(path: '/about', builder: (context, state) => const AboutPage()),
  GoRoute(
    path: '/onboarding',
    builder: (context, state) => const OnboardingPage(),
  ),
  GoRoute(
    path: '/certificate',
    builder: (context, state) => const CertificatePage(),
  ),
  GoRoute(
    path: '/counseling',
    builder: (context, state) => const CounselingListPage(),
  ),
  GoRoute(path: '/chat/:code', builder: (context, state) => const ChatPage()),
  GoRoute(path: '/payment', builder: (context, state) => const PaymentPage()),
  GoRoute(
    path: '/test/:voucher',
    builder: (context, state) => const TestPage(),
  ),
  GoRoute(path: '/result', builder: (context, state) => const ResultPage()),
];

/// The three tabs `AppShell`'s persistent bottom nav wraps (TAHAP 3,
/// MIGRATION_LOG.md's dashboard-shell finding) — matches the old app's
/// `CustomBottomNavBar` (Beranda/Riwayat/Akun) exactly, using the
/// `AppRouter.shellRoutes`/`AppShell` infrastructure `shared` already
/// shipped but nothing wired up until now.
final _shellRoutes = <RouteBase>[
  GoRoute(path: '/home', builder: (context, state) => const HomePage()),
  GoRoute(path: '/history', builder: (context, state) => const HistoryPage()),
  GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
];

final _shellDestinations = <AppShellDestination>[
  AppShellDestination(path: '/home', icon: Icons.home, label: 'Beranda'),
  AppShellDestination(
    path: '/history',
    icon: Icons.history_rounded,
    label: 'Riwayat',
  ),
  AppShellDestination(path: '/profile', icon: Icons.person, label: 'Akun'),
];
