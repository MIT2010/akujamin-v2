import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

import '../../domain/entities/test_history_item.dart';
import '../cubit/history_cubit.dart';
import '../cubit/history_state.dart';

/// Migrated from the old app's `dashboard`'s "Riwayat" tab
/// (`history_page.dart` + `VoucherStateCubit`) — MIGRATION_LOG.md's
/// deliberately narrow first slice of the payment/test/counseling/websocket
/// cluster: read-only, no camera, no websocket, no write-path.
///
/// **`status` is only ever compared against these exact old-app strings**
/// (verified by reading `VoucherList` in full, not guessed): `'Belum Tes'`/
/// `'Sedang Tes'` (still doing the test), `'Konseling'` (in counseling),
/// `'Lulus'` (passed — certificate available), `'Tidak Lulus'`/`'Selesai'`
/// (no further action shown, matching the old app's own
/// `if (isTest || counseling || passed)` guard).
///
/// **Explicit decision, not a dead button** (docs/qa/history.md): "Mulai
/// Tes" (empty state) and "Lanjutkan Tes" lead to features not migrated
/// yet (`payment`'s create-voucher flow, `test`) — tapping them shows
/// `AppDialog.info` saying so, rather than doing nothing or crashing on
/// an unimplemented route. "Lihat Sertifikat" and, since `counseling`'s
/// own migration (docs/qa/counseling.md), "Konseling" are both real —
/// route-string navigation to `/certificate`/`/chat/:code`, no direct
/// package dependency on `feature_history`'s part (§5).
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<HistoryCubit>()..getHistory(),
      child: const HistoryView(),
    );
  }
}

/// Split from [HistoryPage] (left un-exported from the barrel) so widget
/// tests can drive it directly with a fake `HistoryCubit` via
/// `BlocProvider.value` — same pattern as every other feature's page.
class HistoryView extends StatelessWidget {
  const HistoryView({super.key});

  static const _notAvailableMessage =
      'Fitur ini belum tersedia. Coba lagi nanti.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat')),
      body: BlocBuilder<HistoryCubit, HistoryState>(
        builder: (context, state) => switch (state) {
          HistoryInitial() ||
          HistoryLoading() => const Center(child: CircularProgressIndicator()),
          HistoryError(:final failure) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(failure.message),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Coba lagi',
                    onPressed: () => context.read<HistoryCubit>().getHistory(),
                  ),
                ],
              ),
            ),
          ),
          HistoryLoaded(:final items) =>
            items.isEmpty
                ? _EmptyHistory(
                    onStartTest: () => AppDialog.info(
                      context,
                      title: 'Belum tersedia',
                      message: _notAvailableMessage,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) =>
                        _HistoryTile(item: items[index]),
                  ),
        },
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.onStartTest});

  final VoidCallback onStartTest;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Belum ada tes'),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Semua kegiatan dan hasil tes kamu akan dicatat di sini',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(label: 'Mulai Tes', onPressed: onStartTest),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final TestHistoryItem item;

  bool get _isTest => item.status == 'Belum Tes' || item.status == 'Sedang Tes';
  bool get _isCounseling => item.status == 'Konseling';
  bool get _isPassed => item.status == 'Lulus';

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.xs,
          children: [
            _InfoRow(label: 'Kode Voucher', value: item.code),
            _InfoRow(label: 'Lembaga Psikologi', value: item.institution),
            _InfoRow(label: 'Nama Psikolog', value: item.psychologist),
            _InfoRow(label: 'Negara Tujuan', value: item.destinationCountry),
            _InfoRow(label: 'Jenis Pekerjaan', value: item.job),
            _InfoRow(
              label: 'Tanggal Tes',
              value: DateFormat('d MMMM y').format(item.createdAt),
            ),
            _InfoRow(label: 'Ujian Ke', value: item.testAttempt),
            _InfoRow(label: 'Status Ujian', value: item.status),
            _InfoRow(label: 'Keterangan Hasil', value: item.testResult),
            if (_isTest || _isCounseling || _isPassed) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  label: _isTest
                      ? 'Lanjutkan Tes'
                      : _isCounseling
                      ? 'Konseling'
                      : 'Lihat Sertifikat',
                  onPressed: () {
                    if (_isPassed) {
                      context.push(
                        '/certificate?url=${Uri.encodeQueryComponent(item.certificateUrl ?? '')}',
                      );
                      return;
                    }
                    if (_isCounseling) {
                      // Real navigation now that `counseling` is migrated
                      // (feature_history doesn't depend on
                      // feature_counseling directly — route-string
                      // navigation, same as every other cross-feature
                      // link in this app, §5).
                      context.push(
                        '/chat/${item.code}'
                        '?psychologist=${Uri.encodeQueryComponent(item.psychologist)}',
                      );
                      return;
                    }
                    AppDialog.info(
                      context,
                      title: 'Belum tersedia',
                      message: HistoryView._notAvailableMessage,
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.sm,
      children: [
        Expanded(child: Text(label)),
        Expanded(
          flex: 2,
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
