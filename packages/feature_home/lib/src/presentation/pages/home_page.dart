import 'package:authentication/authentication.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import '../cubit/home_cubit.dart';
import '../cubit/home_state.dart';
import '../widgets/home_item_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<HomeCubit>()..loadFeed(),
      child: const HomeView(),
    );
  }
}

/// Split from [HomePage] (and left un-exported from the package barrel) so
/// widget tests can drive it directly with a fake `HomeCubit` via
/// `BlocProvider.value`, without going through `get_it` — same pattern as
/// `authentication`'s `LoginView`.
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
            // Same route-string navigation as the profile button below —
            // features never depend on each other directly (§5).
            onPressed: () => context.push('/about'),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Riwayat',
            // Same route-string navigation as the other buttons here —
            // features never depend on each other directly (§5).
            onPressed: () => context.push('/history'),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Konseling',
            // Same route-string navigation as the other buttons here —
            // features never depend on each other directly (§5).
            onPressed: () => context.push('/counseling'),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Akun',
            // Navigation by route string, not by importing feature_profile —
            // features never depend on each other directly (§5); the route
            // table in apps/mobile is the only place that knows both.
            // `push`, not `go`: keeps /home on the stack so the profile
            // page gets a back button for free.
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () async {
              // Goes through AuthCubit (not AuthRepository directly) so the
              // in-memory session AppRouter reads via AuthSessionAdapter
              // actually flips to unauthenticated — otherwise `context.go`
              // below just bounces straight back to `/home`.
              await getIt<AuthCubit>().logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) => switch (state) {
          HomeInitial() ||
          HomeLoading() => const Center(child: CircularProgressIndicator()),
          HomeError(:final failure) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(failure.message),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Coba lagi',
                    onPressed: () => context.read<HomeCubit>().loadFeed(),
                  ),
                ],
              ),
            ),
          ),
          HomeLoaded(:final items, :final isStale) => Column(
            children: [
              if (isStale) const _StaleBanner(),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) =>
                      HomeItemCard(item: items[index]),
                ),
              ),
            ],
          ),
        },
      ),
    );
  }
}

/// §11's "stale" tag, made visible — data mungkin belum terbaru, ditampilkan
/// bila repository jatuh ke cache lokal karena tidak ada koneksi.
class _StaleBanner extends StatelessWidget {
  const _StaleBanner();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: colors.tertiaryContainer,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 18, color: colors.onTertiaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Data mungkin belum terbaru — menampilkan versi tersimpan terakhir.',
              style: TextStyle(color: colors.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
