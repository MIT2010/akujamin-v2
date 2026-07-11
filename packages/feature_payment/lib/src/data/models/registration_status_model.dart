import '../../domain/entities/registration_status.dart';
import '../../domain/entities/status_voucher.dart';

/// Parses `GET /tes/cek-voucher`'s response envelope:
/// `data.info_registrasi` (`status_ujian`, `kode_voucher`),
/// `data.demografi` (already-filled form values), and `data.pembayaran`
/// (nullable — only present once a voucher has reached the payment
/// step). Confirmed against `PaymentRepoImpl.checkVoucher()` in the old
/// app, not guessed.
abstract class RegistrationStatusModel {
  static RegistrationStatus fromJson({
    required Map<String, dynamic> infoRegistrasi,
    required Map<String, dynamic> demografi,
    Map<String, dynamic>? pembayaran,
  }) {
    final isPaid = pembayaran?['status'] == 'PAID';

    return RegistrationStatus(
      status: _mapStatus(infoRegistrasi['status_ujian'] as String?, isPaid),
      voucherCode: infoRegistrasi['kode_voucher'] as String?,
      formData: demografi.map((k, v) => MapEntry(k, v.toString())),
      isPaid: isPaid,
      proofOfPayment: pembayaran?['bukti'] as String?,
      paidDate: DateTime.tryParse(pembayaran?['tgl_bayar'] as String? ?? ''),
    );
  }

  /// See MIGRATION_LOG.md's "Resolved — payment status codes" section:
  /// `'PT'`/`'TP'` have no confirmed literal expansion, only this
  /// functional mapping, read directly from the old app's
  /// `PaymentStateCubit._mapStatus()`. The `underReview`/`paid` split
  /// beyond that (approved 2026-07-11) additionally depends on
  /// `pembayaran.status`, not on `status_ujian` alone.
  static StatusVoucher _mapStatus(String? raw, bool isPaid) {
    return switch (raw) {
      'PT' => StatusVoucher.needsRegistrationData,
      'TP' => StatusVoucher.needsPayment,
      _ => isPaid ? StatusVoucher.paid : StatusVoucher.underReview,
    };
  }
}
