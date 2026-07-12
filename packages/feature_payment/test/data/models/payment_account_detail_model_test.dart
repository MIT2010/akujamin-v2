import 'package:feature_payment/feature_payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentAccountDetailModel.fromJson', () {
    test('parses the per-psychologist bank account response '
        '(GET /tes/rekening-psikolog/{id})', () {
      final detail = PaymentAccountDetailModel.fromJson({
        'nama_bank': 'Bank Mandiri',
        'no_rekening': '1234567890',
        'price': 150000,
        'expired_at': '2026-07-12T10:00:00.000Z',
      });

      expect(detail.bankName, 'Bank Mandiri');
      expect(detail.bankAccount, '1234567890');
      expect(detail.price, '150000');
      expect(detail.expiredAt, DateTime.parse('2026-07-12T10:00:00.000Z'));
    });

    test('expiredAt is null when the field is missing', () {
      final detail = PaymentAccountDetailModel.fromJson({
        'nama_bank': 'Bank Mandiri',
        'no_rekening': '1234567890',
        'price': 150000,
      });

      expect(detail.expiredAt, isNull);
    });
  });
}
