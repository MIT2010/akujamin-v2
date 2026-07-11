import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/payment_cubit.dart';
import '../cubit/payment_state.dart';

/// Success screen if `pembayaran.status == 'PAID'`, otherwise a waiting
/// screen driven by the `konfirmasi.payment` socket event — with a
/// manual "Cek Status Pembayaran" fallback button, same as the old app,
/// so a missed real-time event never strands the user with no way
/// forward.
class ReviewView extends StatelessWidget {
  const ReviewView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PaymentCubit, PaymentState>(
      buildWhen: (p, c) => p.isPaid != c.isPaid,
      builder: (context, state) {
        return state.isPaid
            ? _PaymentSuccess(voucherCode: state.voucherCode)
            : const _PaymentPending();
      },
    );
  }
}

class _PaymentSuccess extends StatelessWidget {
  const _PaymentSuccess({required this.voucherCode});

  final String? voucherCode;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pembayaran berhasil',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('Kode voucher'),
              Text(
                voucherCode ?? '-',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Gunakan kode voucher ini untuk melanjutkan ke tes psikologi.',
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Gunakan Sekarang',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentPending extends StatelessWidget {
  const _PaymentPending();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Expanded(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    'Konfirmasi Pembayaran',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    'Menunggu konfirmasi pembayaran.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppButton(
            label: 'Cek Status Pembayaran',
            onPressed: context.read<PaymentCubit>().checkPayment,
          ),
        ),
      ],
    );
  }
}
