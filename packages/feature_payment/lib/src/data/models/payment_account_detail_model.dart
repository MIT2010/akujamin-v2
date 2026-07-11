import '../../domain/entities/payment_account_detail.dart';

/// Parses `GET /tes/rekening-psikolog/{id}`'s response — confirmed
/// against the old app's `PaymentModel.fromJson`, which reads
/// `nama_bank`/`no_rekening`/`price`/`expired_at` from the same envelope.
abstract class PaymentAccountDetailModel {
  static PaymentAccountDetail fromJson(Map<String, dynamic> json) {
    return PaymentAccountDetail(
      bankName: json['nama_bank'] as String,
      bankAccount: json['no_rekening'] as String,
      price: json['price'].toString(),
      expiredAt: DateTime.tryParse(json['expired_at'] as String? ?? ''),
    );
  }
}
