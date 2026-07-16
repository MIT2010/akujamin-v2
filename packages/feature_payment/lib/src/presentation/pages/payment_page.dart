import 'package:authentication/authentication.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

import '../cubit/payment_cubit.dart';
import '../cubit/payment_state.dart';
import '../widgets/confirmation_view.dart';
import '../widgets/demography_view.dart';
import '../widgets/payment_method_view.dart';
import '../widgets/review_view.dart';

/// Migrated from the old app's `payment` feature (write-path: create
/// voucher -> demography -> confirmation -> payment -> review). See
/// MIGRATION_LOG.md for the full write-path audit this was built from.
class PaymentPage extends StatelessWidget {
  const PaymentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      bloc: getIt<AuthCubit>(),
      builder: (context, state) {
        final userId = switch (state) {
          AuthAuthenticated(:final user) => user.id,
          _ => null,
        };

        return BlocProvider(
          create: (_) => getIt<PaymentCubit>()..initialize(userId ?? ''),
          child: const PaymentView(),
        );
      },
    );
  }
}

/// Split from [PaymentPage] (left un-exported from the barrel) so widget
/// tests can drive it directly with a fake `PaymentCubit` via
/// `BlocProvider.value` — same pattern as every other feature's page.
class PaymentView extends StatelessWidget {
  const PaymentView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<PaymentCubit, PaymentState>(
      listenWhen: (p, c) => p.isFailed != c.isFailed || p.error != c.error,
      listener: (context, state) {
        if (!state.isFailed || state.error == null) return;

        // Real behavior from the old app's `PaymentPage`'s BlocListener:
        // any failure while on the payment step bounces back to
        // demography, not just a validation error inside that step.
        if (state.step == PaymentStep.payment) {
          context.read<PaymentCubit>().backToDemography();
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.error!.message)));
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Pembayaran')),
        body: BlocBuilder<PaymentCubit, PaymentState>(
          buildWhen: (p, c) => p.step != c.step,
          builder: (context, state) {
            if (state.step == PaymentStep.checking) {
              return const Center(child: CircularProgressIndicator());
            }

            return Column(
              children: [
                const _StepHeader(),
                Expanded(
                  child: switch (state.step) {
                    PaymentStep.demography => const DemographyView(),
                    PaymentStep.confirmation => const ConfirmationView(),
                    PaymentStep.payment => const PaymentMethodView(),
                    PaymentStep.review => const ReviewView(),
                    PaymentStep.checking => const SizedBox.shrink(),
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader();

  static const _steps = [
    (PaymentStep.demography, 'Pendaftaran'),
    (PaymentStep.confirmation, 'Konfirmasi'),
    (PaymentStep.payment, 'Pembayaran'),
    (PaymentStep.review, 'Status'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PaymentCubit, PaymentState, PaymentStep>(
      selector: (state) => state.step,
      builder: (context, step) {
        final currentIndex = _steps.indexWhere((s) => s.$1 == step);

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              for (final (index, entry) in _steps.indexed) ...[
                if (index > 0) const Expanded(child: Divider()),
                _StepDot(
                  label: entry.$2,
                  isDone: index < currentIndex,
                  isCurrent: index == currentIndex,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.label,
    required this.isDone,
    required this.isCurrent,
  });

  final String label;
  final bool isDone;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final color = isDone || isCurrent
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outline;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isDone ? Icons.check_circle : Icons.circle_outlined,
          color: color,
          size: 20,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(label, style: TextStyle(color: color, fontSize: 11)),
      ],
    );
  }
}
