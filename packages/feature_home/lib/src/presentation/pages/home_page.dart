import 'package:authentication/authentication.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthCubit>.value(
      value: getIt<AuthCubit>(),
      child: const HomeView(),
    );
  }
}

/// Split from [HomePage] (and left un-exported from the package barrel) so
/// widget tests can drive it directly with a fake `AuthCubit` via
/// `BlocProvider.value`, without going through `get_it` — same pattern as
/// `feature_profile`'s `ProfileView`.
///
/// **Body content replaced 2026-07-14, found during the reconciliation
/// audit, not a port**: this used to render a `HomeCubit`-driven paginated
/// `HomeItem` feed backed by a Hive cache — confirmed, by checking against
/// `flutter_starter_kit` (the template this project was bootstrapped from),
/// to be generic starter-kit demo content that predates every migration
/// decision in this repo, not something derived from the old app's real
/// dashboard home screen at all. The old app's actual home screen (`dashboard/
/// presentation/pages/home_page.dart`) showed a profile teaser and an
/// incomplete-profile nudge — that's what's built here instead. The old
/// screen's menu grid (about/counseling/payment) already has a live
/// equivalent in this file's own `AppBar` icons below (ported earlier), so
/// it isn't rebuilt a second time. `HomeCubit`/`HomeItem`/the Hive cache
/// layer were deleted, not left behind unused — see MIGRATION_LOG.md.
/// Riwayat and Akun used to have their own AppBar icons here, pushing
/// `/history`/`/profile` directly. Removed once `apps/mobile` wired
/// `AppRouter.shellRoutes`/`AppShell` (TAHAP 3, MIGRATION_LOG.md's
/// dashboard-shell finding) — those two destinations are reachable from the
/// persistent bottom-nav on every shell screen now, so the AppBar icons
/// were a live duplicate, not a fallback.
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Onboarding',
            // Same route-string navigation as the other buttons here —
            // features never depend on each other directly (§5). Old app
            // auto-showed this pre-login on first launch; manual entry
            // point here instead (docs/qa/onboarding.md's tracked
            // simplification, ADR-010's minimal-wiring bar).
            onPressed: () => context.push('/onboarding'),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'FAQ',
            // Same route-string navigation as the other buttons here —
            // features never depend on each other directly (§5).
            onPressed: () => context.push('/about'),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Konseling',
            // Same route-string navigation as the other buttons here —
            // features never depend on each other directly (§5).
            onPressed: () => context.push('/counseling'),
          ),
          IconButton(
            icon: const Icon(Icons.payment_outlined),
            tooltip: 'Pembayaran',
            // Mandatory gate (not the bare route-string push the other
            // buttons here use): the old app's "Tes Psikologi" menu checks
            // `!user.isRegistered` before ever reaching payment
            // (`home_menu_config.dart`), redirecting to `register` instead
            // — a real access gate, not a decorative banner. This button
            // had no such check until now, a live gap this migration only
            // just found (`register` didn't exist yet when `payment` was
            // wired up). `context.push<bool>('/register')` — a `bool?`
            // result, discarded here on purpose: `RegisterCubit.submit()`
            // already refreshes `AuthCubit`'s session on success, so the
            // next tap of this same button re-reads the now-current
            // `isRegistered` from `AuthCubit.state` itself, no manual
            // re-check needed.
            onPressed: () async {
              final user = switch (context.read<AuthCubit>().state) {
                AuthAuthenticated(:final user) => user,
                _ => null,
              };

              if (user != null && !user.isRegistered) {
                await context.push<bool>('/register');
                return;
              }

              if (context.mounted) context.push('/payment');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () async {
              // context.read, not getIt directly: HomePage already provides
              // the singleton via BlocProvider.value, so descendants read
              // it from there (testable with a fake AuthCubit) — same
              // pattern as ProfilePage's logout button.
              await context.read<AuthCubit>().logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) => switch (state) {
          AuthAuthenticated(:final user, :final sessionProfile) => ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _ProfileTeaser(user: user, sessionProfile: sessionProfile),
              if (!user.isRegistered) ...[
                const SizedBox(height: AppSpacing.md),
                const _IncompleteProfileBanner(),
              ],
            ],
          ),
          // Session still restoring, or somehow reached /home unauthenticated
          // (AppRouter._redirect should prevent the latter) — nothing real
          // to show yet, same "nothing to render before state resolves"
          // stance as ProfileView.
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}

/// Avatar + name teaser, migrated from the old app's real dashboard home
/// screen (`dashboard/presentation/pages/home_page.dart`) — not the
/// synthetic content this replaced. `sessionProfile` is `null` for the
/// email/password `LoginCubit` flow (which never populates one, see
/// `AuthState`'s doc comment); falls back to the account's email in that
/// case rather than showing nothing.
class _ProfileTeaser extends StatelessWidget {
  const _ProfileTeaser({required this.user, required this.sessionProfile});

  final User user;
  final SessionProfile? sessionProfile;

  @override
  Widget build(BuildContext context) {
    final avatar = sessionProfile?.avatar ?? '';
    final displayName = sessionProfile?.name ?? user.email;

    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, $displayName',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(user.email, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ported from the old app's `home_menu_config.dart` gate — the same
/// `!user.isRegistered` check the Payment `IconButton` above enforces,
/// surfaced here as a visible nudge instead of only a silent redirect the
/// moment someone happens to tap Payment.
class _IncompleteProfileBanner extends StatelessWidget {
  const _IncompleteProfileBanner();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppCard(
      onTap: () => context.push<bool>('/register'),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: colors.tertiary),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text(
              'Lengkapi profil kamu (KTP + selfie) untuk bisa melakukan '
              'pembayaran tes.',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.chevron_right, color: colors.tertiary),
        ],
      ),
    );
  }
}
