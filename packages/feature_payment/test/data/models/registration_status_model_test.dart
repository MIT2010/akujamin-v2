import 'package:feature_payment/feature_payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RegistrationStatusModel.fromJson', () {
    test("maps 'PT' to needsRegistrationData", () {
      final status = RegistrationStatusModel.fromJson(
        infoRegistrasi: {'status_ujian': 'PT', 'kode_voucher': null},
        demografi: {},
      );

      expect(status.status, StatusVoucher.needsRegistrationData);
    });

    test("maps 'TP' to needsPayment", () {
      final status = RegistrationStatusModel.fromJson(
        infoRegistrasi: {'status_ujian': 'TP'},
        demografi: {},
      );

      expect(status.status, StatusVoucher.needsPayment);
    });

    test('maps anything else to underReview when pembayaran.status is not '
        "'PAID' — no confirmed literal value beyond PT/TP exists, so this "
        'must not guess a third literal code', () {
      final status = RegistrationStatusModel.fromJson(
        infoRegistrasi: {'status_ujian': 'anything-else'},
        demografi: {},
        pembayaran: {'status': 'PENDING'},
      );

      expect(status.status, StatusVoucher.underReview);
      expect(status.isPaid, isFalse);
    });

    test("maps to paid when pembayaran.status == 'PAID'", () {
      final status = RegistrationStatusModel.fromJson(
        infoRegistrasi: {'status_ujian': 'anything-else'},
        demografi: {},
        pembayaran: {'status': 'PAID', 'bukti': 'https://x/y.jpg'},
      );

      expect(status.status, StatusVoucher.paid);
      expect(status.isPaid, isTrue);
      expect(status.proofOfPayment, 'https://x/y.jpg');
    });

    test('carries the voucher code and demography form values through', () {
      final status = RegistrationStatusModel.fromJson(
        infoRegistrasi: {'status_ujian': 'PT', 'kode_voucher': 'ABC123'},
        demografi: {'psikologi': '27', 'pendidikan': '01'},
      );

      expect(status.voucherCode, 'ABC123');
      expect(status.formData, {'psikologi': '27', 'pendidikan': '01'});
    });

    test('pembayaran being entirely absent (no payment step reached yet) '
        'defaults isPaid to false, not a crash', () {
      final status = RegistrationStatusModel.fromJson(
        infoRegistrasi: {'status_ujian': 'PT'},
        demografi: {},
        pembayaran: null,
      );

      expect(status.isPaid, isFalse);
      expect(status.proofOfPayment, isNull);
    });
  });
}
