import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import '../cubit/onboarding_cubit.dart';
import '../cubit/onboarding_state.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<OnboardingCubit>()..checkStatus(),
      child: const OnboardingView(),
    );
  }
}

/// Split from [OnboardingPage] (and left un-exported from the package
/// barrel) so widget tests can drive it directly with a fake
/// `OnboardingCubit` via `BlocProvider.value`, without going through
/// `get_it` — same pattern as every other feature's page.
///
/// A `StatefulWidget`, not stateless: owns the `PageController` driving
/// the carousel, same reason `feature_profile`'s `ProfileView` is
/// stateful (§23) — the old app's `OnboardingPage` used the identical
/// `PageController` + `NeverScrollableScrollPhysics` + `nextPage()`
/// shape, kept here for direct behavior traceability.
///
/// **Fixed 2026-07-16, no longer just a manual entry point** (see
/// docs/qa/onboarding.md and the akujamin-app comparison audit):
/// `AppRouter`'s redirect now replicates the old app's real router-level
/// gate — an unauthenticated, genuine-first-launch session is forced
/// here automatically, the same way `AuthStateCubit`'s redirect did in
/// the old app (`FirstLaunchGate`, `shared`/`packages/shared/lib/src/
/// router/first_launch_gate.dart`). The manual entry point (an icon on
/// Home) still exists as an additional way to reach this page once
/// already authenticated, same as before.
class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => OnboardingViewState();
}

class OnboardingViewState extends State<OnboardingView> {
  final _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<OnboardingCubit, OnboardingState>(
          listener: (context, state) {
            switch (state) {
              case OnboardingFinished() || OnboardingAlreadyCompleted():
                context.go('/home');
              case OnboardingChecking() ||
                  OnboardingShowCarousel() ||
                  OnboardingCompleting() ||
                  OnboardingError():
                break;
            }
          },
          builder: (context, state) => switch (state) {
            OnboardingChecking() ||
            OnboardingAlreadyCompleted() ||
            OnboardingFinished() => const Center(
              child: CircularProgressIndicator(),
            ),
            OnboardingError(:final failure) => Center(
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
                          context.read<OnboardingCubit>().checkStatus(),
                    ),
                  ],
                ),
              ),
            ),
            OnboardingShowCarousel() || OnboardingCompleting() => PageView(
              controller: _controller,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _OnboardingSlide(
                  icon: Icons.info_outline,
                  title: 'Selamat Datang di AKUJAMIN',
                  description:
                      'AKUJAMIN adalah asesmen psikologis untuk menilai '
                      'kesiapan calon Pekerja Migran Indonesia (PMI) '
                      'sebelum bekerja di luar negeri. Penilaian dilakukan '
                      'secara sistematis terhadap aspek mental, emosional, '
                      'dan sosial guna mendukung kesiapan menghadapi '
                      'dinamika kerja internasional.',
                  buttonLabel: 'Lanjut',
                  onPressed: _next,
                ),
                _OnboardingSlide(
                  icon: Icons.psychology_outlined,
                  title: 'Kenapa pilih AKUJAMIN',
                  description:
                      'Bekerja di luar negeri menuntut ketahanan menghadapi '
                      'tekanan, kemampuan adaptasi budaya, dan kesiapan '
                      'sosial. AKUJAMIN memberikan gambaran objektif '
                      'tentang kesiapan tersebut, membantu calon PMI '
                      'melakukan refleksi dan mempersiapkan diri secara '
                      'terarah.',
                  buttonLabel: 'Lanjut',
                  onPressed: _next,
                ),
                _OnboardingSlide(
                  icon: Icons.camera_alt_outlined,
                  title: 'Akses Kamera',
                  description:
                      'Aplikasi ini memerlukan akses kamera pada tahap '
                      'verifikasi identitas dan selama pengerjaan tes. '
                      'Apabila akses kamera tidak diberikan, proses '
                      'verifikasi tidak dapat dilakukan sehingga layanan '
                      'AKUJAMIN tidak dapat digunakan.',
                  buttonLabel: 'Lanjut',
                  onPressed: _next,
                ),
                _OnboardingSlide(
                  icon: Icons.badge_outlined,
                  title: 'Verifikasi Wajah & KTP',
                  description:
                      '• Siapkan KTP-el untuk verifikasi identitas.\n'
                      '• Pastikan seluruh wajah terlihat jelas di area '
                      'kamera saat proses verifikasi wajah.\n'
                      '• Kedua tahap tersebut wajib diselesaikan untuk '
                      'mengakses layanan AKUJAMIN.',
                  buttonLabel: 'Mulai',
                  loading: state is OnboardingCompleting,
                  onPressed: () => context.read<OnboardingCubit>().complete(),
                ),
              ],
            ),
          },
        ),
      ),
    );
  }
}

/// Simplified from the old app's `OnboardingItem`: an [Icon] instead of
/// the old app's real brand image assets (`ImageAsset.icon`,
/// `ImageAsset.ktpScan`, etc.) — those aren't available to port into this
/// repo. Deliberate, tracked simplification (docs/qa/onboarding.md), not
/// an oversight; the actual copy text is kept verbatim from the old app
/// since it's real user-facing consent language (camera/KTP disclosure),
/// not placeholder content.
class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Text(
            title,
            style: AppTypography.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Icon(icon, size: 96, color: AppColors.primary),
          const SizedBox(height: AppSpacing.lg),
          Text(
            description,
            style: AppTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          AppButton(label: buttonLabel, loading: loading, onPressed: onPressed),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
