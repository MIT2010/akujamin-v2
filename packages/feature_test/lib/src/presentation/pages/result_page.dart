import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Static "tes selesai, menunggu pemeriksaan psikolog" screen — no cubit,
/// no network call, matching the old app's `ResultPage` exactly (it never
/// had one either).
class ResultPage extends StatelessWidget {
  const ResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.task_alt, size: 96, color: Colors.green),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Selesai',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Selamat, kamu sudah menyelesaikan semua tes. Hasil tes '
                'kamu sedang diperiksa oleh psikolog.\n\nKami akan '
                'memberi tahu kamu begitu hasilnya sudah keluar.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(label: 'Beranda', onPressed: () => context.go('/home')),
            ],
          ),
        ),
      ),
    );
  }
}
