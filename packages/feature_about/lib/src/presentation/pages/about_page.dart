import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

import '../../domain/entities/about.dart';
import '../cubit/about_cubit.dart';
import '../cubit/about_state.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AboutCubit>()..getAbout(),
      child: const AboutView(),
    );
  }
}

/// Split from [AboutPage] (and left un-exported from the package barrel) so
/// widget tests can drive it directly with a fake `AboutCubit` via
/// `BlocProvider.value`, without going through `get_it` — same pattern as
/// every other feature's page.
///
/// Renders the FAQ list itself (one [ExpansionTile] per entry) instead of
/// the old app's split shape (the list lived in `dashboard`, and
/// `AboutPage` itself only rendered one item's text read from route
/// `extra`) — AUDIT.md §4's caveat #1 flagged that split as something the
/// migration should fix, not carry over (§0's golden rule: migrate
/// behavior, not structure).
///
/// Content renders via [AppMarkdownText] — closes the gap tracked since
/// this pilot first shipped (AUDIT.md §3 flagged real markdown rendering
/// as future `design_system` work; deliberately deferred then so the
/// pilot stayed scoped to proving the data/DI/state pattern). Built as
/// part of migrating `test`, whose intro/instruction content also uses
/// markdown — see MIGRATION_LOG.md.
class AboutView extends StatelessWidget {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FAQ')),
      body: BlocBuilder<AboutCubit, AboutState>(
        builder: (context, state) => switch (state) {
          AboutInitial() ||
          AboutLoading() => const Center(child: CircularProgressIndicator()),
          AboutError(:final failure) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(failure.message),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Coba lagi',
                    onPressed: () => context.read<AboutCubit>().getAbout(),
                  ),
                ],
              ),
            ),
          ),
          AboutLoaded(:final items) =>
            items.isEmpty
                ? const Center(child: Text('Belum ada FAQ.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) =>
                        _AboutTile(item: items[index]),
                  ),
        },
      ),
    );
  }
}

class _AboutTile extends StatelessWidget {
  const _AboutTile({required this.item});

  final About item;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        title: Text(item.type),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [AppMarkdownText(data: item.text)],
      ),
    );
  }
}
