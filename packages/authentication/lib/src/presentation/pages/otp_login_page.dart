import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import '../cubit/otp_login_cubit.dart';
import '../cubit/otp_login_state.dart';

/// Reached via [Navigator.push] from [LoginView] (not a `GoRoute`) —
/// deliberate: `AppRouter._redirect`'s `loggingIn` check is an *exact*
/// match on `state.matchedLocation == '/login'`
/// (`packages/shared/lib/src/router/app_router.dart`), so a sibling
/// top-level route like `/login/otp` would fail that check and bounce an
/// unauthenticated user straight back to `/login`. Pushing this page
/// locally on top of `/login` keeps the router's location at `/login`
/// throughout, so the existing `loggedIn && loggingIn -> /home` redirect
/// fires automatically the moment `AuthCubit.setAuthenticated` runs — no
/// change to `shared` needed for this feature. See docs/qa/auth_login.md.
class OtpLoginPage extends StatelessWidget {
  const OtpLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<OtpLoginCubit>(),
      child: const OtpLoginView(),
    );
  }
}

/// Split from [OtpLoginPage] (left un-exported from the barrel), same
/// reason as [LoginView]: widget tests drive it directly with a fake
/// `OtpLoginCubit` via `BlocProvider.value`.
class OtpLoginView extends StatefulWidget {
  const OtpLoginView({super.key});

  @override
  State<OtpLoginView> createState() => OtpLoginViewState();
}

class OtpLoginViewState extends State<OtpLoginView> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Masuk dengan nomor telepon')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: BlocConsumer<OtpLoginCubit, OtpLoginState>(
          listener: (context, state) {
            // Redundant with AppRouter's own redirect (see the class doc)
            // but kept explicit for consistency with LoginView's pattern
            // and to navigate immediately without waiting on a rebuild.
            if (state is OtpLoginSuccessState) context.go('/home');
          },
          builder: (context, state) => switch (state) {
            OtpLoginPhoneEntry() => _PhoneEntryForm(
              controller: _phoneController,
              loading: false,
              onSubmit: () =>
                  context.read<OtpLoginCubit>().sendOtp(_phoneController.text),
            ),
            OtpLoginSendingOtp() => _PhoneEntryForm(
              controller: _phoneController,
              loading: true,
              onSubmit: () =>
                  context.read<OtpLoginCubit>().sendOtp(_phoneController.text),
            ),
            OtpLoginSendOtpFailure(:final failure) => _PhoneEntryForm(
              controller: _phoneController,
              loading: false,
              errorText: failure.message,
              onSubmit: () =>
                  context.read<OtpLoginCubit>().sendOtp(_phoneController.text),
            ),
            OtpLoginOtpEntry(:final phoneNumber, :final expiresAt) =>
              _OtpEntryForm(
                controller: _otpController,
                phoneNumber: phoneNumber,
                expiresAt: expiresAt,
                loading: false,
                onSubmit: () => context.read<OtpLoginCubit>().verifyOtp(
                  phoneNumber: phoneNumber,
                  otpCode: _otpController.text,
                  expiresAt: expiresAt,
                ),
                onResend: () =>
                    context.read<OtpLoginCubit>().resendOtp(phoneNumber),
              ),
            OtpLoginVerifyingOtp(:final phoneNumber, :final expiresAt) =>
              _OtpEntryForm(
                controller: _otpController,
                phoneNumber: phoneNumber,
                expiresAt: expiresAt,
                loading: true,
                onSubmit: () => context.read<OtpLoginCubit>().verifyOtp(
                  phoneNumber: phoneNumber,
                  otpCode: _otpController.text,
                  expiresAt: expiresAt,
                ),
                onResend: () =>
                    context.read<OtpLoginCubit>().resendOtp(phoneNumber),
              ),
            OtpLoginVerifyOtpFailure(
              :final failure,
              :final phoneNumber,
              :final expiresAt,
            ) =>
              _OtpEntryForm(
                controller: _otpController,
                phoneNumber: phoneNumber,
                expiresAt: expiresAt,
                loading: false,
                errorText: failure.message,
                onSubmit: () => context.read<OtpLoginCubit>().verifyOtp(
                  phoneNumber: phoneNumber,
                  otpCode: _otpController.text,
                  expiresAt: expiresAt,
                ),
                onResend: () =>
                    context.read<OtpLoginCubit>().resendOtp(phoneNumber),
              ),
            OtpLoginSuccessState() => const Center(
              child: CircularProgressIndicator(),
            ),
          },
        ),
      ),
    );
  }
}

class _PhoneEntryForm extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final String? errorText;
  final VoidCallback onSubmit;

  const _PhoneEntryForm({
    required this.controller,
    required this.loading,
    required this.onSubmit,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppTextField(
          label: 'Nomor telepon',
          controller: controller,
          errorText: errorText,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(label: 'Kirim OTP', loading: loading, onPressed: onSubmit),
      ],
    );
  }
}

class _OtpEntryForm extends StatelessWidget {
  final TextEditingController controller;
  final String phoneNumber;
  final DateTime expiresAt;
  final bool loading;
  final String? errorText;
  final VoidCallback onSubmit;
  final VoidCallback onResend;

  const _OtpEntryForm({
    required this.controller,
    required this.phoneNumber,
    required this.expiresAt,
    required this.loading,
    required this.onSubmit,
    required this.onResend,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Kode OTP dikirim ke $phoneNumber'),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: 'Kode OTP',
          controller: controller,
          errorText: errorText,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(label: 'Verifikasi', loading: loading, onPressed: onSubmit),
        const SizedBox(height: AppSpacing.sm),
        const Text('Belum dapat kode?', textAlign: TextAlign.center),
        _ResendCountdown(expiresAt: expiresAt, onResend: onResend),
      ],
    );
  }
}

/// Ported from the old app's `otp_page.dart` countdown/resend `TextButton`
/// (`AuthStateCubit._startCountdown`/`_tick`) -- real gap, found
/// 2026-07-16: this had no counterpart at all until now. Owns its own
/// `Timer` locally (ticks purely off wall-clock time against `expiresAt`,
/// already present in [OtpLoginState]) instead of threading a live
/// countdown through the cubit's state, since nothing else in this app's
/// business logic needs to know the remaining seconds -- only this one
/// button's enabled/disabled label does.
class _ResendCountdown extends StatefulWidget {
  const _ResendCountdown({required this.expiresAt, required this.onResend});

  final DateTime expiresAt;
  final VoidCallback onResend;

  @override
  State<_ResendCountdown> createState() => _ResendCountdownState();
}

class _ResendCountdownState extends State<_ResendCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restartTicking();
  }

  @override
  void didUpdateWidget(covariant _ResendCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A successful resend moves `expiresAt` forward -- restart the tick
    // loop so a stale, already-cancelled Timer from the previous
    // countdown doesn't leave the button permanently stuck.
    if (oldWidget.expiresAt != widget.expiresAt) _restartTicking();
  }

  void _restartTicking() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.expiresAt.difference(DateTime.now());
    final isExpired = remaining.isNegative;
    if (isExpired) _timer?.cancel();

    final clamped = isExpired ? Duration.zero : remaining;
    final minutes = clamped.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = clamped.inSeconds.remainder(60).toString().padLeft(2, '0');

    return TextButton(
      onPressed: isExpired ? widget.onResend : null,
      child: Text(
        isExpired ? 'Kirim Ulang' : 'Kirim ulang dalam $minutes:$seconds',
      ),
    );
  }
}
