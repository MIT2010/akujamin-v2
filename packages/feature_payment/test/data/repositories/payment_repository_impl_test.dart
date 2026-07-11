import 'package:core/core.dart';
import 'package:feature_payment/feature_payment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPaymentRemoteDataSource extends Mock
    implements PaymentRemoteDataSource {}

class _MockPaymentLocalDataSource extends Mock
    implements PaymentLocalDataSource {}

void main() {
  late _MockPaymentRemoteDataSource remote;
  late _MockPaymentLocalDataSource local;
  late PaymentRepositoryImpl repository;

  setUp(() {
    remote = _MockPaymentRemoteDataSource();
    local = _MockPaymentLocalDataSource();
    repository = PaymentRepositoryImpl(remote, local);
  });

  group('PaymentRepositoryImpl.checkVoucher', () {
    test('maps the envelope into a RegistrationStatus on status: ok', () async {
      when(() => remote.checkVoucher()).thenAnswer(
        (_) async => Ok(<String, dynamic>{
          'status': 'ok',
          'data': {
            'info_registrasi': {'status_ujian': 'TP', 'kode_voucher': 'ABC'},
            'demografi': {'psikologi': '27'},
            'pembayaran': null,
          },
        }),
      );

      final result = await repository.checkVoucher();

      expect(result.isOk, isTrue);
      final status = (result as Ok<Failure, RegistrationStatus>).value;
      expect(status.status, StatusVoucher.needsPayment);
      expect(status.voucherCode, 'ABC');
    });

    test('returns Err when the envelope status is not ok', () async {
      when(() => remote.checkVoucher()).thenAnswer(
        (_) async => Ok(<String, dynamic>{
          'status': 'error',
          'message': 'Voucher tidak ditemukan',
        }),
      );

      final result = await repository.checkVoucher();

      expect(result.isErr, isTrue);
      expect(
        (result as Err<Failure, RegistrationStatus>).failure.message,
        'Voucher tidak ditemukan',
      );
    });

    test('propagates a datasource failure as-is', () async {
      when(() => remote.checkVoucher()).thenAnswer(
        (_) async => const Err(NetworkFailure()),
      );

      final result = await repository.checkVoucher();

      expect(result.isErr, isTrue);
      expect(
        (result as Err<Failure, RegistrationStatus>).failure,
        isA<NetworkFailure>(),
      );
    });
  });

  group('PaymentRepositoryImpl.createVoucher', () {
    test('returns the new kode_voucher on success', () async {
      when(() => remote.createVoucher(any())).thenAnswer(
        (_) async => Ok(<String, dynamic>{
          'status': 'ok',
          'kode_voucher': 'NEWCODE123',
        }),
      );

      final result = await repository.createVoucher({'psikologi': '27'});

      expect(result.isOk, isTrue);
      expect((result as Ok<Failure, String>).value, 'NEWCODE123');
    });
  });

  group('PaymentRepositoryImpl.getPaymentAccount', () {
    test('parses the per-psychologist bank account', () async {
      when(() => remote.getPaymentAccount('27')).thenAnswer(
        (_) async => Ok(<String, dynamic>{
          'status': 'ok',
          'data': {
            'nama_bank': 'Bank Mandiri',
            'no_rekening': '123',
            'price': 150000,
          },
        }),
      );

      final result = await repository.getPaymentAccount('27');

      expect(result.isOk, isTrue);
      expect(
        (result as Ok<Failure, PaymentAccountDetail>).value.bankName,
        'Bank Mandiri',
      );
    });
  });

  group('PaymentRepositoryImpl.checkPayment', () {
    test('returns isPaid + voucherCode as a record', () async {
      when(() => remote.checkPayment()).thenAnswer(
        (_) async => Ok(<String, dynamic>{
          'status': 'ok',
          'data': {'status': 'PAID', 'kode_voucher': 'ABC123'},
        }),
      );

      final result = await repository.checkPayment();

      expect(result.isOk, isTrue);
      final checkResult = (result as Ok<Failure, PaymentCheckResult>).value;
      expect(checkResult.isPaid, isTrue);
      expect(checkResult.voucherCode, 'ABC123');
    });
  });

  group('PaymentRepositoryImpl psychologist-id passthrough', () {
    test('delegates directly to PaymentLocalDataSource', () async {
      when(() => local.getPsychologistId()).thenAnswer((_) async => 'conf.27');
      when(() => local.savePsychologistId(any())).thenAnswer((_) async {});
      when(() => local.clearPsychologistId()).thenAnswer((_) async {});

      expect(await repository.getPsychologistId(), 'conf.27');
      await repository.savePsychologistId('conf.27');
      await repository.clearPsychologistId();

      verify(() => local.savePsychologistId('conf.27')).called(1);
      verify(() => local.clearPsychologistId()).called(1);
    });
  });
}
