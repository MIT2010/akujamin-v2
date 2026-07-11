import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/payment_cubit.dart';

/// Waiting screen shown while the selected psychologist confirms the
/// voucher (real-time, via the `konfirmasi.user` socket event). The
/// 5-minute fallback timeout matches the old app's `ConfirmationView`
/// exactly — if the psychologist never responds, the user is bounced
/// back to demography with an explanatory message rather than waiting
/// forever.
class ConfirmationView extends StatefulWidget {
  const ConfirmationView({super.key});

  @override
  State<ConfirmationView> createState() => _ConfirmationViewState();
}

class _ConfirmationViewState extends State<ConfirmationView> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(minutes: 5), () {
      context.read<PaymentCubit>().backToDemography(
        message: 'Psikolog tidak merespon. Silahkan pilih Psikolog lain.',
      );
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.md),
            Text(
              'Konfirmasi Psikolog',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Menunggu konfirmasi dari psikolog yang dipilih.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
