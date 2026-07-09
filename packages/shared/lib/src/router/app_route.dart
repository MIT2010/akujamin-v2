import 'package:go_router/go_router.dart';

/// A [GoRoute] that also carries the roles allowed to view it (§13's
/// "RoleGuard"). [AppRouter]'s own top-level `redirect` reads this
/// straight off `GoRouterState.topRoute` — a real go_router mechanism —
/// so role checks stay in the same redirect function instead of needing
/// a separate guard framework.
///
/// Features that don't care about roles keep using a plain [GoRoute];
/// this subclass is opt-in.
class AppRoute extends GoRoute {
  final List<String> roles;

  AppRoute({
    required super.path,
    super.name,
    super.builder,
    super.pageBuilder,
    super.parentNavigatorKey,
    super.redirect,
    super.onExit,
    super.caseSensitive,
    super.routes,
    this.roles = const [],
  });
}
