import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/payment_account_detail.dart';
import '../../domain/entities/registration_status.dart';
import '../../domain/repositories/payment_repository.dart';
import '../datasources/payment_local_datasource.dart';
import '../datasources/payment_remote_datasource.dart';
import '../models/payment_account_detail_model.dart';
import '../models/registration_status_model.dart';

@LazySingleton(as: PaymentRepository)
class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentRemoteDataSource _remote;
  final PaymentLocalDataSource _local;
  PaymentRepositoryImpl(this._remote, this._local);

  Failure? _envelopeError(Map<String, dynamic> envelope) {
    if (envelope['status'] == 'ok') return null;
    return ServerFailure(envelope['message'] as String? ?? 'Terjadi kesalahan');
  }

  @override
  Future<Result<Failure, RegistrationStatus>> checkVoucher() async {
    final result = await _remote.checkVoucher();

    return result.fold(Err.new, (envelope) {
      final error = _envelopeError(envelope);
      if (error != null) return Err(error);

      final data = envelope['data'] as Map<String, dynamic>;
      return Ok(
        RegistrationStatusModel.fromJson(
          infoRegistrasi: data['info_registrasi'] as Map<String, dynamic>,
          demografi: data['demografi'] as Map<String, dynamic>,
          pembayaran: data['pembayaran'] as Map<String, dynamic>?,
        ),
      );
    });
  }

  @override
  Future<Result<Failure, String>> createVoucher(
    Map<String, String> formData,
  ) async {
    final result = await _remote.createVoucher(formData);

    return result.fold(Err.new, (envelope) {
      final error = _envelopeError(envelope);
      if (error != null) return Err(error);

      return Ok(envelope['kode_voucher'] as String);
    });
  }

  @override
  Future<Result<Failure, void>> cancelVoucher() async {
    final result = await _remote.cancelVoucher();

    return result.fold(Err.new, (envelope) {
      final error = _envelopeError(envelope);
      if (error != null) return Err(error);

      return const Ok(null);
    });
  }

  @override
  Future<Result<Failure, PaymentAccountDetail>> getPaymentAccount(
    String psychologistId,
  ) async {
    final result = await _remote.getPaymentAccount(psychologistId);

    return result.fold(Err.new, (envelope) {
      final error = _envelopeError(envelope);
      if (error != null) return Err(error);

      return Ok(
        PaymentAccountDetailModel.fromJson(
          envelope['data'] as Map<String, dynamic>,
        ),
      );
    });
  }

  @override
  Future<Result<Failure, void>> sendPayment(String imagePath) async {
    final result = await _remote.sendPayment(imagePath);

    return result.fold(Err.new, (envelope) {
      final error = _envelopeError(envelope);
      if (error != null) return Err(error);

      return const Ok(null);
    });
  }

  @override
  Future<Result<Failure, PaymentCheckResult>> checkPayment() async {
    final result = await _remote.checkPayment();

    return result.fold(Err.new, (envelope) {
      final error = _envelopeError(envelope);
      if (error != null) return Err(error);

      final data = envelope['data'] as Map<String, dynamic>;
      return Ok((
        isPaid: data['status'] == 'PAID',
        voucherCode: data['kode_voucher'] as String?,
      ));
    });
  }

  @override
  Future<String?> getPsychologistId() => _local.getPsychologistId();

  @override
  Future<void> savePsychologistId(String id) => _local.savePsychologistId(id);

  @override
  Future<void> clearPsychologistId() => _local.clearPsychologistId();
}
