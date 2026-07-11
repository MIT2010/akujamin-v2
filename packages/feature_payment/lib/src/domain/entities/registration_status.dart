import 'package:freezed_annotation/freezed_annotation.dart';

import 'status_voucher.dart';

part 'registration_status.freezed.dart';

/// Result of `GET /tes/cek-voucher` — the entry point of the payment
/// flow, checked on every load to decide which step to resume on.
///
/// [isPaid]/[proofOfPayment]/[paidDate] come from the response's nested
/// `pembayaran` block — kept as named, typed fields here rather than a
/// raw `Map<String, dynamic>?` the way the old app's `RegisEntity` carried
/// it forward to be merged later by [PaymentAccountDetail]'s caller.
@freezed
abstract class RegistrationStatus with _$RegistrationStatus {
  const factory RegistrationStatus({
    required StatusVoucher status,
    required Map<String, String> formData,
    String? voucherCode,
    @Default(false) bool isPaid,
    String? proofOfPayment,
    DateTime? paidDate,
  }) = _RegistrationStatus;
}
