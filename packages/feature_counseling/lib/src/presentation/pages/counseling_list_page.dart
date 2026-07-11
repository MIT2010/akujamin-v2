import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

import '../../domain/entities/counseling_session.dart';
import '../cubit/counseling_cubit.dart';
import '../cubit/counseling_state.dart';

/// Migrated from the old app's `counseling/presentation/pages/
/// counseling_page.dart` — the session list. Read-only, fetch-once, no
/// websocket (that's `ChatPage`'s job for one thread at a time).
class CounselingListPage extends StatelessWidget {
  const CounselingListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<CounselingCubit>()..getSessions(),
      child: const CounselingListView(),
    );
  }
}

/// Split from [CounselingListPage] (left un-exported from the barrel) so
/// widget tests can drive it directly with a fake `CounselingCubit` via
/// `BlocProvider.value` — same pattern as every other feature's page.
class CounselingListView extends StatelessWidget {
  const CounselingListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Konseling')),
      body: BlocBuilder<CounselingCubit, CounselingState>(
        builder: (context, state) => switch (state) {
          CounselingInitial() || CounselingLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          CounselingError(:final failure) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(failure.message),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Coba lagi',
                    onPressed: () =>
                        context.read<CounselingCubit>().getSessions(),
                  ),
                ],
              ),
            ),
          ),
          CounselingLoaded(:final sessions) =>
            sessions.isEmpty
                ? const Center(child: Text('Belum ada sesi konseling'))
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: sessions.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) =>
                        _SessionTile(session: sessions[index]),
                  ),
        },
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final CounselingSession session;

  bool get _isFinished => session.status == 'finished';

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xs,
        children: [
          Text(
            session.psychologist,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(DateFormat('d MMMM y').format(session.createdAt)),
          Text('Status: ${session.status}'),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'Chat',
              onPressed: _isFinished
                  ? null
                  : () => context.push(
                      '/chat/${session.code}'
                      '?psychologist=${Uri.encodeQueryComponent(session.psychologist)}',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
