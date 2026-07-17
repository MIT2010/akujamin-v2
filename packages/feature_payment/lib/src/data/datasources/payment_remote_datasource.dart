import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';

/// Thin wrapper over the seven `/tes/*` write-path endpoints — deliberately
/// excludes `GET /tes/list-voucher` (already `feature_history`'s) and
/// `POST /tes/kirim-penilaian` (confirmed by the Postman collection to
/// exist on the backend but never called by the old app's own
/// `PaymentApiService` — belongs to a future `test` feature, not this
/// one). Also excludes the `/payment/method`, `/payment/notif`,
/// `/payment/checkout` gateway endpoints — confirmed unused anywhere in
/// the old app's shipped `PaymentApiService` (7-method interface, read in
/// full); this migration only needs the manual-transfer-and-upload-proof
/// flow the app actually ships.
@injectable
class PaymentRemoteDataSource {
  final ApiClient _client;
  PaymentRemoteDataSource(this._client);

  Future<Result<Failure, Map<String, dynamic>>> checkVoucher() {
    return _client.get<Map<String, dynamic>>(
      '/tes/cek-voucher',
      parser: (json) => json as Map<String, dynamic>,
    );
  }

  Future<Result<Failure, Map<String, dynamic>>> createVoucher(
    Map<String, String> formData,
  ) {
    return _client.post<Map<String, dynamic>>(
      '/tes/create',
      data: FormData.fromMap(formData),
      parser: (json) => json as Map<String, dynamic>,
    );
  }

  Future<Result<Failure, Map<String, dynamic>>> cancelVoucher() {
    return _client.get<Map<String, dynamic>>(
      '/tes/batal-tes',
      parser: (json) => json as Map<String, dynamic>,
    );
  }

  Future<Result<Failure, Map<String, dynamic>>> getPaymentAccount(
    String psychologistId,
  ) {
    return _client.get<Map<String, dynamic>>(
      '/tes/rekening-psikolog/$psychologistId',
      parser: (json) => json as Map<String, dynamic>,
    );
  }

  /// `imagePath` is nullable to match the old app's own
  /// `PaymentApiService.sendPayment({MultipartFile? param})` -- real gap,
  /// found 2026-07-16 during the akujamin-app comparison audit: resuming
  /// a payment whose proof was already uploaded in a previous session
  /// still has to reach this endpoint (the old app always calls it,
  /// passing `null` for `bukti` when there's nothing new to upload) so
  /// the server can move the voucher into review. `FormData.fromMap`
  /// (Dio) omits a `null` entry entirely, so passing `null` here sends
  /// the exact same empty-`bukti` request the old app does.
  ///
  /// Reads via `XFile.readAsBytes()` + `MultipartFile.fromBytes`, not
  /// `MultipartFile.fromFile` -- real bug, found 2026-07-17: `fromFile`
  /// reads through dart:io internally, which throws "Unsupported
  /// operation: _Namespace" on Flutter Web the same way a direct
  /// `File(path).readAsBytes()` call does (`imagePath` is a `blob:` URL
  /// on web, not a real filesystem path).
  Future<Result<Failure, Map<String, dynamic>>> sendPayment(
    String? imagePath,
  ) async {
    MultipartFile? bukti;
    if (imagePath != null) {
      final bytes = await XFile(imagePath).readAsBytes();
      bukti = MultipartFile.fromBytes(bytes, filename: 'bukti.jpg');
    }

    return _client.multipart<Map<String, dynamic>>(
      '/tes/kirim-pembayaran',
      data: FormData.fromMap({'bukti': bukti}),
      parser: (json) => json as Map<String, dynamic>,
    );
  }

  Future<Result<Failure, Map<String, dynamic>>> checkPayment() {
    return _client.get<Map<String, dynamic>>(
      '/payment/cek-pembayaran',
      parser: (json) => json as Map<String, dynamic>,
    );
  }
}
