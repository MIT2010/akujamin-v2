import 'dart:async';
import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:shared/shared.dart';

import '../../domain/entities/status_voucher.dart';
import '../../domain/repositories/payment_repository.dart';
import 'payment_state.dart';

/// No UseCase (§21/ADR-004) — every `PaymentRepository` method is a thin
/// pass-through (all nine of the old app's usecases read, confirmed zero
/// real orchestration during the write-path audit), same conclusion as
/// `about`/`onboarding`/`history`/`counseling`. The realtime + countdown
/// wiring below is orchestration this cubit genuinely owns.
///
/// [SocketGateway] is `shared`'s app-wide single connection (MIGRATION_LOG.md
/// permanent finding #1's resolution) — not a `feature_payment`-private one
/// anymore, shared with `counseling` and the `dashboard` shell.
@injectable
class PaymentCubit extends Cubit<PaymentState> {
  PaymentCubit(this._repository, this._formInputRepository, this._socketGateway)
    : super(const PaymentState());

  final PaymentRepository _repository;
  final FormInputRepository _formInputRepository;
  final SocketGateway _socketGateway;
  final ImagePicker _picker = ImagePicker();

  StreamSubscription<SocketEvent>? _eventSubscription;
  Timer? _countdownTimer;
  String? _userId;
  bool _socketConnected = false;

  // =========================================================
  // INITIALIZATION
  // =========================================================

  Future<void> initialize(String userId) async {
    _userId = userId;
    await _checkVoucher();
  }

  Future<void> _checkVoucher() async {
    emit(state.copyWith(isLoading: true, isFailed: false));
    final result = await _repository.checkVoucher();

    await result.fold(
      (failure) async {
        emit(state.copyWith(isLoading: false, isFailed: true, error: failure));
      },
      (regStatus) async {
        emit(
          state.copyWith(
            isLoading: false,
            voucherCode: regStatus.voucherCode,
            formResults: regStatus.formData,
            isPaid: regStatus.isPaid,
            existingProofUrl: regStatus.proofOfPayment,
          ),
        );

        switch (regStatus.status) {
          case StatusVoucher.needsRegistrationData:
            emit(state.copyWith(step: PaymentStep.demography));
            await _loadForms();
          case StatusVoucher.needsPayment:
            await _connectSocket();
            await _loadPaymentAccount();
          case StatusVoucher.underReview:
          case StatusVoucher.paid:
            await _connectSocket();
            emit(state.copyWith(step: PaymentStep.review));
        }
      },
    );
  }

  // =========================================================
  // FORMS (demography step)
  // =========================================================

  Future<void> _loadForms() async {
    final result = await _formInputRepository.getForm('/tes/pertanyaan');

    result.fold(
      (failure) => emit(state.copyWith(isFailed: true, error: failure)),
      (forms) => emit(state.copyWith(forms: forms)),
    );
  }

  /// Applies the mandatory clear-on-parent-change fix (approved
  /// 2026-07-11) — a dependent field's stale value is removed from
  /// `formResults` the moment its parent changes, for two independent
  /// reasons: this feeds a real write path (`createVoucher`), and
  /// Flutter's `DropdownButtonFormField` throws if handed a value that
  /// isn't in its (now re-filtered) options.
  void setInput(String label, String value) {
    final updated = Map<String, String>.from(state.formResults)
      ..[label] = value;
    final cleared = clearDependentFields(label, state.forms, updated);
    emit(state.copyWith(formResults: cleared));
  }

  String? validateForms() {
    for (final form in state.forms) {
      if (state.formResults[form.label] == null) {
        return '${form.display} masih kosong';
      }
    }
    return null;
  }

  void backToDemography({String? message}) {
    emit(
      state.copyWith(
        step: PaymentStep.demography,
        isFailed: message != null,
        error: message != null ? ValidationFailure(message) : null,
      ),
    );
    _loadForms();
  }

  // =========================================================
  // VOUCHER
  // =========================================================

  Future<void> goToConfirmation() async {
    final error = validateForms();
    if (error != null) {
      emit(state.copyWith(isFailed: true, error: ValidationFailure(error)));
      return;
    }

    await _connectSocket();
    await _createVoucher();
  }

  Future<void> _createVoucher() async {
    emit(state.copyWith(isLoading: true, isFailed: false));
    final result = await _repository.createVoucher(state.formResults);

    result.fold(
      (failure) => emit(
        state.copyWith(isLoading: false, isFailed: true, error: failure),
      ),
      (voucherCode) => emit(
        state.copyWith(
          isLoading: false,
          voucherCode: voucherCode,
          step: PaymentStep.confirmation,
        ),
      ),
    );
  }

  Future<void> cancelVoucher() async {
    if (state.step == PaymentStep.review) return;
    await _repository.cancelVoucher();
  }

  // =========================================================
  // PAYMENT ACCOUNT (bank details, per-psychologist)
  // =========================================================

  Future<void> _loadPaymentAccount() async {
    emit(state.copyWith(step: PaymentStep.payment));

    final psychologistId = state.formResults['psikologi'];
    if (psychologistId == null) return;

    final result = await _repository.getPaymentAccount(psychologistId);

    result.fold(
      (failure) => emit(state.copyWith(isFailed: true, error: failure)),
      (account) {
        emit(state.copyWith(account: account));
        if (account.expiredAt != null) _startCountdown(account.expiredAt!);
      },
    );
  }

  // =========================================================
  // PROOF OF PAYMENT IMAGE
  // =========================================================

  Future<void> pickImage(ImageSource source) async {
    final image = await _picker.pickImage(source: source, imageQuality: 70);
    if (image == null) return;
    emit(state.copyWith(pickedImagePath: image.path));
  }

  void removeImage() {
    emit(state.copyWith(pickedImagePath: null));
  }

  /// Real gap, found 2026-07-16 during the akujamin-app comparison audit:
  /// resuming a payment with an already-uploaded proof (`pickedImagePath
  /// == null && existingProofUrl != null`) used to skip
  /// `_repository.sendPayment` entirely and jump straight to
  /// [PaymentStep.review] locally. The old app's equivalent
  /// (`PaymentStateCubit.submitPayment`, `hasUploadedProof` vs
  /// `hasExistingProof`) always calls the server in that case too,
  /// passing `null` for the file -- if `/tes/kirim-pembayaran` does
  /// anything server-side beyond storing a file (e.g. flipping the
  /// voucher into review, notifying the assigned psychologist), the old
  /// call path was the only one that actually triggered it. Restored to
  /// match: the network call is unconditional now, only the multipart
  /// file itself is optional.
  Future<void> submitPayment() async {
    final path = state.pickedImagePath;
    if (path == null && state.existingProofUrl == null) {
      emit(
        state.copyWith(
          isFailed: true,
          error: const ValidationFailure(
            'Bukti pembayaran tidak boleh kosong.',
          ),
        ),
      );
      return;
    }

    emit(state.copyWith(isLoading: true, isFailed: false));
    final result = await _repository.sendPayment(path);

    await result.fold(
      (failure) async {
        emit(state.copyWith(isLoading: false, isFailed: true, error: failure));
      },
      (_) async {
        if (path != null) await _cleanupProofImage(path);
        emit(
          state.copyWith(
            isLoading: false,
            step: PaymentStep.review,
            pickedImagePath: null,
          ),
        );
      },
    );
  }

  /// Mandatory fix, not ported: the old app never cleaned up the captured
  /// proof-of-payment image file — a second, independent instance of
  /// permanent finding #4's class of gap, this time a financial document
  /// (bank transfer receipt) rather than a face image. Best-effort only:
  /// a cleanup failure must never block a payment that already succeeded
  /// server-side.
  Future<void> _cleanupProofImage(String path) async {
    // No filesystem to clean up on web -- `path` is a `blob:` URL there,
    // not a real file, and dart:io's `File` throws "Unsupported
    // operation" the moment it's touched at all (real bug, found
    // 2026-07-17). The browser garbage-collects the underlying blob
    // itself once nothing references it anymore; nothing to do here.
    if (kIsWeb) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best-effort only — see doc comment above.
    }
  }

  Future<void> checkPayment() async {
    final result = await _repository.checkPayment();

    result.fold(
      (failure) => emit(state.copyWith(isFailed: true, error: failure)),
      (checkResult) => emit(
        state.copyWith(
          isPaid: checkResult.isPaid,
          voucherCode: checkResult.voucherCode ?? state.voucherCode,
        ),
      ),
    );
  }

  // =========================================================
  // SOCKET
  // =========================================================

  Future<void> _connectSocket() async {
    if (_socketConnected) return;

    final psychologistId = state.formResults['psikologi'];
    if (psychologistId == null) return;

    _socketConnected = true;
    final channelName = 'conf.$psychologistId';

    await _repository.savePsychologistId(channelName);
    await _eventSubscription?.cancel();

    _eventSubscription = _socketGateway.events.listen((event) {
      if (event.payload['from'] != 'psikolog.$_userId') return;

      switch (event.type) {
        case 'konfirmasi.user':
          _loadPaymentAccount();
        case 'konfirmasi.payment':
          checkPayment();
      }
    });

    await _socketGateway.subscribe(channelName);
  }

  /// Approved fix (MIGRATION_LOG.md's "Resolved — payment status codes"
  /// section): always unsubscribes and clears, with no "skip if status is
  /// review" exception like the old app had — that asymmetry left a
  /// channel subscription alive in the shared gateway with nothing left
  /// listening to it. `subscribeIfNotUnsubscribed()` (proven safe by
  /// `counseling`) makes re-entering payment later safe regardless.
  Future<void> disconnectSocket() async {
    final channelName = await _repository.getPsychologistId();

    if (channelName != null) {
      await _socketGateway.unsubscribe(channelName);
      await _repository.clearPsychologistId();
    }

    await _eventSubscription?.cancel();
    _eventSubscription = null;
    _socketConnected = false;
  }

  // =========================================================
  // COUNTDOWN
  // =========================================================

  void _startCountdown(DateTime expiredAt) {
    _countdownTimer?.cancel();
    _updateCountdown(expiredAt);
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateCountdown(expiredAt),
    );
  }

  void _updateCountdown(DateTime expiredAt) {
    final remaining = expiredAt.difference(DateTime.now());

    if (remaining.isNegative) {
      _countdownTimer?.cancel();
      emit(state.copyWith(remaining: Duration.zero, isExpired: true));
      return;
    }

    emit(state.copyWith(remaining: remaining, isExpired: false));
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  Future<void> close() async {
    await disconnectSocket();
    _countdownTimer?.cancel();
    return super.close();
  }
}
