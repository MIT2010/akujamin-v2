import 'package:freezed_annotation/freezed_annotation.dart';

part 'payment_account_detail.freezed.dart';

/// The bank account to transfer to for one voucher's payment — fetched
/// via `GET /tes/rekening-psikolog/{psychologistId}`. **Per-psychologist,
/// not one central company account** — confirmed by the endpoint shape
/// itself (a psychologist ID as the path parameter), a real behavior
/// nuance carried over from the write-path audit, not obvious from the
/// field names alone.
@freezed
abstract class PaymentAccountDetail with _$PaymentAccountDetail {
  const factory PaymentAccountDetail({
    required String bankName,
    required String bankAccount,
    required String price,
    DateTime? expiredAt,
  }) = _PaymentAccountDetail;
}
