import 'package:authentication/authentication.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

/// Migrated from the old app's real `dashboard/presentation/pages/
/// account_page.dart` — not the synthetic name/email/bio/phoneNumber edit
/// form this package started as (MIGRATION_LOG.md's `dashboard` row).
/// `AccountPage` there was read-only (avatar/name/nik, no `TextField`
/// anywhere) plus a logout button; the "Ganti Password" button was
/// commented-out dead code with no usecase/repository/endpoint behind it
/// anywhere in the old codebase (grepped for it — confirmed). Migrating
/// *behavior*, not the aspirational UI that was never actually wired up.
///
/// No repository/datasource/UseCase of its own: `avatar`/`name`/`nik` come
/// from `AuthCubit.state.sessionProfile`, populated by the same `/auth/me`
/// fetch login already makes (`authentication`'s `SessionProfile` —
/// deliberately kept separate from `User`, see that class's doc comment,
/// so `nik` never flows into session-scoped observability calls like
/// `CrashReporter.setUserId`/`AnalyticsService.setUserId`). One source of
/// truth, not a second copy of the same data.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthCubit>.value(
      value: getIt<AuthCubit>(),
      child: const ProfileView(),
    );
  }
}

/// Split from [ProfilePage] (and left un-exported from the package barrel)
/// so widget tests can drive it directly with a fake `AuthCubit` via
/// `BlocProvider.value`, without going through `get_it` — same pattern as
/// every other feature's page.
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Akun')),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) => switch (state) {
          AuthAuthenticated(:final sessionProfile?) => _AccountDetails(
            profile: sessionProfile,
          ),
          // AuthAuthenticated with no cached sessionProfile yet (e.g. the
          // synthetic email/password LoginCubit flow, which never sets
          // one), or a session still restoring — same as old app having
          // nothing to show before `getProfile()` resolves.
          _ => const Center(
            child: Text('Belum ada data akun untuk ditampilkan.'),
          ),
        },
      ),
    );
  }
}

class _AccountDetails extends StatelessWidget {
  const _AccountDetails({required this.profile});

  final SessionProfile profile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: profile.avatar.isNotEmpty
                ? NetworkImage(profile.avatar)
                : null,
            child: profile.avatar.isEmpty
                ? const Icon(Icons.person, size: 50)
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(profile.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(profile.nik, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: 'Logout', onPressed: () => _confirmLogout(context)),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Logout',
      message:
          'Apakah kamu yakin untuk keluar? Kamu harus login lagi untuk '
          'menggunakan aplikasi.',
      confirmLabel: 'Logout',
      cancelLabel: 'Batal',
    );
    if (confirmed != true || !context.mounted) return;

    // context.read, not getIt directly: ProfilePage already provides the
    // singleton via BlocProvider.value, so descendants read it from there
    // (testable with a fake AuthCubit, same as every other feature's
    // page). Goes through AuthCubit (not AuthRepository directly) so the
    // in-memory session AppRouter reads via AuthSessionAdapter actually
    // flips to unauthenticated — otherwise `context.go` below just
    // bounces straight back here — same reasoning as HomeView's logout
    // button.
    await context.read<AuthCubit>().logout();
    if (context.mounted) context.go('/login');
  }
}
