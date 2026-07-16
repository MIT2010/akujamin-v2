import 'package:core/core.dart';

import '../entities/payment_account_detail.dart';
import '../entities/registration_status.dart';

/// Result of `GET /tes/cek-pembayaran` — deliberately not folded into
/// [RegistrationStatus] since it's a distinct call the user can trigger
/// manually (the review step's "Cek Status Pembayaran" button), not a
/// re-fetch of the same resource.
typedef PaymentCheckResult = ({bool isPaid, String? voucherCode});

/// Abstract contract for the payment write-path. No UseCase in front of
/// this (§21/ADR-004) — every method below is a thin pass-through in the
/// old app's `payment` usecases (all nine read, confirmed zero real
/// orchestration), same conclusion as `about`/`onboarding`/`history`/
/// `counseling`.
abstract class PaymentRepository {
  Future<Result<Failure, RegistrationStatus>> checkVoucher();

  Future<Result<Failure, String>> createVoucher(Map<String, String> formData);

  Future<Result<Failure, void>> cancelVoucher();

  Future<Result<Failure, PaymentAccountDetail>> getPaymentAccount(
    String psychologistId,
  );

  /// `imagePath` is nullable so a resume-with-existing-proof still
  /// reaches the server (see `PaymentRemoteDataSource.sendPayment`'s doc
  /// comment) instead of being handled entirely client-side.
  Future<Result<Failure, void>> sendPayment(String? imagePath);

  Future<Result<Failure, PaymentCheckResult>> checkPayment();

  Future<String?> getPsychologistId();

  Future<void> savePsychologistId(String id);

  Future<void> clearPsychologistId();
}
