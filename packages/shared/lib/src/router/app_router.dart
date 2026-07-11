import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';

import 'app_route.dart';
import 'app_shell.dart';
import 'auth_session.dart';
import 'feature_routes.dart';
import 'go_router_refresh_stream.dart';
import 'not_found_page.dart';

/// The single `go_router` config for the app (§13, §17). Routes are never
/// hardcoded here — every feature contributes its own [FeatureRoutes].
///
/// [standaloneRoutes], [shellRoutes] and [shellDestinations] are populated
/// by the composition root (`apps/mobile`, once it exists) by flattening
/// every registered [FeatureRoutes.routes] — plain lists assembled in
/// `main.dart`, not resolved through `get_it`, because get_it has no
/// built-in "give me every implementation of this interface as a List"
/// constructor injection; only `AuthSession` (a single, always-resolvable
/// dependency) goes through DI here. This keeps `AppRouter` itself
/// constructible — and testable — before any feature package exists.
@lazySingleton
class AppRouter {
  final AuthSession _authSession;

  AppRouter(this._authSession);

  /// Routes outside the persistent bottom nav, e.g. `/login`. Must be set
  /// before [router] is first read.
  List<RouteBase> standaloneRoutes = const [];

  /// Routes rendered inside the [ShellRoute] (persistent bottom nav).
  /// Must be set before [router] is first read.
  List<RouteBase> shellRoutes = const [];

  /// The bottom-nav tabs matching [shellRoutes]. Empty means no
  /// [ShellRoute] is built at all — every route is standalone.
  List<AppShellDestination> shellDestinations = const [];

  late final GoRouter router = GoRouter(
    refreshListenable: GoRouterRefreshStream(_authSession.statusStream),
    redirect: _redirect,
    routes: [
      ...standaloneRoutes,
      if (shellRoutes.isNotEmpty)
        ShellRoute(
          builder: (context, state, child) =>
              AppShell(destinations: shellDestinations, child: child),
          routes: shellRoutes,
        ),
    ],
    errorBuilder: (context, state) => const NotFoundPage(),
  );

  /// Handles the auth gate (loggedIn/loggingIn) and the role guard (§13's
  /// "RoleGuard") in one place, as asked — no separate guard framework.
  /// The role check reads `state.topRoute`, which is only populated for
  /// [AppRoute] (a plain [GoRoute] has no roles to check).
  String? _redirect(BuildContext context, GoRouterState state) {
    final status = _authSession.status;
    final loggedIn = status.isAuthenticated;
    final loggingIn = state.matchedLocation == '/login';

    if (!loggedIn && !loggingIn) return '/login';
    if (loggedIn && loggingIn) return '/home';

    final matchedRoute = state.topRoute;

    // GoRouter defaults to '/' when no initialLocation is given (true of
    // every real caller here — apps/mobile never sets one), and this app
    // never registers a route for '/' itself. Left unhandled, a logged-in
    // user landing there — which is exactly what happens on every cold
    // start once a session is restored from disk, not just a theoretical
    // path — falls through to NotFoundPage instead of a sensible screen.
    // Scoped to '/' specifically (not every unmatched location) so a real
    // 404 on a genuinely bad route still shows NotFoundPage.
    if (loggedIn && matchedRoute == null && state.uri.path == '/') {
      return '/home';
    }

    if (matchedRoute is AppRoute && matchedRoute.roles.isNotEmpty) {
      final hasRequiredRole = matchedRoute.roles.any(status.roles.contains);
      if (!hasRequiredRole) return '/home';
    }

    return null;
  }
}
