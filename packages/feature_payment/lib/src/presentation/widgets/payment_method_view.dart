import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../cubit/payment_cubit.dart';
import '../cubit/payment_state.dart';

/// Bank transfer details (per-psychologist, not one central account) +
/// proof-of-payment upload. Camera **and** gallery are both offered, same
/// as the old app — the iOS/Android camera-permission gap this exposed
/// was fixed at the platform config level (`Info.plist`/
/// `AndroidManifest.xml`) as part of this slice, since this is the first
/// real camera consumer being migrated.
class PaymentMethodView extends StatelessWidget {
  const PaymentMethodView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PaymentCubit, PaymentState>(
      buildWhen: (p, c) => p.account != c.account,
      builder: (context, state) {
        final account = state.account;
        if (account == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Text(
                    'Transfer',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Text('Silahkan transfer ke rekening di bawah ini.'),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nama Bank'),
                        Text(
                          account.bankName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text('Nomor Rekening'),
                        GestureDetector(
                          onTap: () async {
                            await Clipboard.setData(
                              ClipboardData(text: account.bankAccount),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Nomor rekening berhasil disalin'),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.copy_rounded, size: 18),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                account.bankAccount,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text('Nominal'),
                        Text(
                          account.price,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const _ExpirationCountdown(),
                        const SizedBox(height: AppSpacing.md),
                        const _ProofOfPaymentPicker(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AppButton(
                label: 'Selanjutnya',
                loading: state.isLoading,
                onPressed: context.read<PaymentCubit>().submitPayment,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ExpirationCountdown extends StatelessWidget {
  const _ExpirationCountdown();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PaymentCubit, PaymentState>(
      buildWhen: (p, c) => p.isExpired != c.isExpired || p.remaining != c.remaining,
      builder: (context, state) {
        if (state.isExpired) {
          return const Text(
            'Expired',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red),
          );
        }

        final duration = state.remaining ?? Duration.zero;
        final hours = duration.inHours.remainder(60).toString().padLeft(2, '0');
        final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
        final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

        return Text(
          'Lakukan pembayaran sebelum $hours:$minutes:$seconds',
          style: const TextStyle(fontWeight: FontWeight.w700),
        );
      },
    );
  }
}

class _ProofOfPaymentPicker extends StatelessWidget {
  const _ProofOfPaymentPicker();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PaymentCubit, PaymentState>(
      buildWhen: (p, c) =>
          p.pickedImagePath != c.pickedImagePath ||
          p.existingProofUrl != c.existingProofUrl,
      builder: (context, state) {
        final localPath = state.pickedImagePath;
        final existingUrl = state.existingProofUrl;
        final hasImage = localPath != null || existingUrl != null;

        return GestureDetector(
          onTap: hasImage
              ? null
              : () async {
                  final source = await showModalBottomSheet<ImageSource>(
                    context: context,
                    builder: (_) => const _ImageSourceChoices(),
                  );
                  if (source == null) return;
                  if (!context.mounted) return;
                  context.read<PaymentCubit>().pickImage(source);
                },
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: hasImage
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      localPath != null
                          ? Image.file(File(localPath), fit: BoxFit.contain)
                          : Image.network(existingUrl!, fit: BoxFit.contain),
                      if (localPath != null)
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            onPressed: () =>
                                context.read<PaymentCubit>().removeImage(),
                            icon: const Icon(
                              Icons.cancel_outlined,
                              color: Colors.red,
                            ),
                          ),
                        ),
                    ],
                  )
                : const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image_rounded, size: 64),
                        SizedBox(height: AppSpacing.sm),
                        Text('Bukti Pembayaran'),
                        Text('Tekan untuk upload bukti pembayaran'),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _ImageSourceChoices extends StatelessWidget {
  const _ImageSourceChoices();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Choice(
            icon: Icons.camera_alt_outlined,
            label: 'Kamera',
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          _Choice(
            icon: Icons.photo_outlined,
            label: 'Galeri',
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: AppSpacing.sm),
          Text(label),
        ],
      ),
    );
  }
}
