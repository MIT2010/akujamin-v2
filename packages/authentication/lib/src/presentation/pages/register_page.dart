import 'dart:io';

import 'package:camera/camera.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

import '../cubit/register_cubit.dart';
import '../cubit/register_state.dart';
import '../cubit/selfie_camera_cubit.dart';
import '../cubit/selfie_camera_state.dart';

/// Migrated from the old app's `register` flow (KTP+selfie, part of
/// `auth`'s own feature folder there — this package's own description
/// already anticipated it: "Login/register/token refresh domain + data +
/// minimal UI"). See MIGRATION_LOG.md's `register` row and
/// docs/qa/register.md for the full audit this was built from.
///
/// Reached via `context.push<bool>('/register')` (a real `GoRoute`, unlike
/// `OtpLoginPage`'s `Navigator.push` workaround — `/register` has no
/// special case in `AppRouter._redirect`, an authenticated user landing on
/// it just falls through the normal `loggedIn` branch and renders
/// normally). Pops `true` on success so the caller (`feature_home`'s
/// Payment button) can refresh its own view of `User.isRegistered`.
class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<SelfieCameraCubit>()..initCamera()),
        BlocProvider(create: (_) => getIt<RegisterCubit>()),
      ],
      child: const RegisterView(),
    );
  }
}

/// Split from [RegisterPage] (left un-exported from the barrel) so widget
/// tests can drive it directly with fake cubits via `BlocProvider.value` —
/// same pattern as every other feature's page in this migration.
class RegisterView extends StatelessWidget {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<SelfieCameraCubit, SelfieCameraState>(
          listenWhen: (p, c) => p.imagePath != c.imagePath,
          listener: (context, state) {
            if (state.imagePath != null) {
              context.read<RegisterCubit>().setSelfiePath(state.imagePath!);
            }
          },
        ),
        BlocListener<RegisterCubit, RegisterState>(
          listenWhen: (p, c) => p.error != c.error || p.status != c.status,
          listener: (context, state) {
            if (state.error != null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.error!.message)));
            }
            if (state.status == RegisterStatus.success) {
              Navigator.of(context).pop(true);
            }
          },
        ),
      ],
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;

          final confirmed = await AppDialog.confirm(
            context,
            title: 'Keluar dari registrasi?',
            message: 'Data yang sudah diisi akan hilang.',
            confirmLabel: 'Keluar',
            cancelLabel: 'Batal',
          );

          if (confirmed == true && context.mounted) {
            Navigator.of(context).pop(false);
          }
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('Lengkapi Profil')),
          body: BlocBuilder<RegisterCubit, RegisterState>(
            buildWhen: (p, c) => p.status != c.status,
            builder: (context, state) => switch (state.status) {
              RegisterStatus.takingSelfie ||
              RegisterStatus.selfieTaken => const SelfieCaptureView(),
              RegisterStatus.loadingForm => const Center(
                child: CircularProgressIndicator(),
              ),
              RegisterStatus.inputForm ||
              RegisterStatus.extractingKtp ||
              RegisterStatus.ktpExtracted => const RegistrationFormView(),
              RegisterStatus.submitting => const _StatusMessage(
                icon: Icons.hourglass_top,
                title: 'Mengirim...',
                message: 'Ini mungkin akan memakan waktu.',
                isLoading: true,
              ),
              RegisterStatus.success => const _StatusMessage(
                icon: Icons.check_circle,
                title: 'Registrasi berhasil',
                message: 'Profil kamu sudah lengkap.',
              ),
              RegisterStatus.failed => _StatusMessage(
                icon: Icons.error_outline,
                title: 'Registrasi gagal',
                message: state.error?.message ?? 'Terjadi kesalahan.',
              ),
            },
          ),
        ),
      ),
    );
  }
}

/// Camera preview / captured-photo confirmation — no ML Kit, no live face
/// detection (confirmed during the register audit: the old app's selfie
/// flow is a still capture only, unlike `test`'s live proctoring).
class SelfieCaptureView extends StatelessWidget {
  const SelfieCaptureView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selfie',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const Text('Foto selfie dulu sebelum isi data diri.'),
          const SizedBox(height: AppSpacing.md),
          Expanded(child: _CameraOrPreview()),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Mohon untuk melepas',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Wrap(
            spacing: AppSpacing.sm,
            children: [
              Chip(label: Text('Kacamata')),
              Chip(label: Text('Topi')),
              Chip(label: Text('Masker')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const _SelfieActionRow(),
        ],
      ),
    );
  }
}

class _CameraOrPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RegisterCubit, RegisterState>(
      buildWhen: (p, c) => p.status != c.status || p.selfiePath != c.selfiePath,
      builder: (context, registerState) {
        if (registerState.status == RegisterStatus.selfieTaken &&
            registerState.selfiePath != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(registerState.selfiePath!),
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          );
        }

        return BlocBuilder<SelfieCameraCubit, SelfieCameraState>(
          builder: (context, camState) {
            if (camState.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (camState.error != null) {
              return Center(child: Text(camState.error!.message));
            }

            final controller = context
                .read<SelfieCameraCubit>()
                .gateway
                .controller;
            if (!camState.isReady || controller == null) {
              return const SizedBox.shrink();
            }

            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: CameraPreview(controller),
              ),
            );
          },
        );
      },
    );
  }
}

class _SelfieActionRow extends StatelessWidget {
  const _SelfieActionRow();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RegisterCubit, RegisterState>(
      buildWhen: (p, c) => p.status != c.status,
      builder: (context, state) {
        if (state.status == RegisterStatus.selfieTaken) {
          return Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Ulangi',
                  onPressed: () {
                    context.read<SelfieCameraCubit>().resumePreview();
                    context.read<RegisterCubit>().retakeSelfie();
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'Lanjutkan',
                  onPressed: () => context.read<RegisterCubit>().loadForm(),
                ),
              ),
            ],
          );
        }

        return Center(
          child: IconButton(
            iconSize: 64,
            icon: const Icon(Icons.camera),
            onPressed: () => context.read<SelfieCameraCubit>().takePhoto(),
          ),
        );
      },
    );
  }
}

/// KTP scan button + the `form_input`-driven schema (`/registrasi/profile`
/// — this feature's confirmed second/third consumer of `DynamicFormField`,
/// same widget `payment`'s `DemographyView` already uses).
class RegistrationFormView extends StatelessWidget {
  const RegistrationFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RegisterCubit, RegisterState>(
      buildWhen: (p, c) =>
          p.status != c.status ||
          p.forms != c.forms ||
          p.formResults != c.formResults,
      builder: (context, state) {
        final cubit = context.read<RegisterCubit>();
        final extracting = state.status == RegisterStatus.extractingKtp;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  IconButton(
                    iconSize: 56,
                    icon: extracting
                        ? const CircularProgressIndicator()
                        : const Icon(Icons.document_scanner_outlined),
                    onPressed: extracting ? null : cubit.scanKtp,
                  ),
                  Text(
                    extracting ? 'Mengekstrak KTP...' : 'Ekstrak data KTP',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (state.status == RegisterStatus.ktpExtracted)
                    const Text(
                      'Data KTP berhasil diekstrak',
                      style: TextStyle(color: Colors.green),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                itemCount: state.forms.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final form = state.forms[index];
                  final options = filterCascadingOptions(
                    form,
                    state.formResults,
                  );

                  return DynamicFormField(
                    label: form.display,
                    type: _mapType(form.type),
                    value: state.formResults[form.label],
                    validate: form.validate,
                    readOnly: form.readOnly,
                    options: options
                        ?.map(
                          (o) =>
                              DynamicFormOption(label: o.label, value: o.value),
                        )
                        .toList(),
                    onChanged: (value) => cubit.setInput(form.label, value),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AppButton(label: 'Lanjutkan', onPressed: cubit.submit),
            ),
          ],
        );
      },
    );
  }

  DynamicFormFieldType _mapType(String type) => switch (type) {
    'date' => DynamicFormFieldType.date,
    'select' => DynamicFormFieldType.select,
    _ => DynamicFormFieldType.text,
  };
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.isLoading = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 96),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (isLoading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
