import 'dart:typed_data';

import 'package:core/core.dart';

/// Abstract contract (§18). Implemented by [CertificateRepositoryImpl].
/// Separate from [HistoryRepository] deliberately — "download and view one
/// certificate PDF" is its own bounded action (§1's classification test),
/// not a variant of "fetch the history list."
abstract class CertificateRepository {
  Future<Result<Failure, Uint8List>> download(String url);
}
