import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

import '../../domain/repositories/certificate_repository.dart';
import '../datasources/certificate_remote_datasource.dart';

@LazySingleton(as: CertificateRepository)
class CertificateRepositoryImpl implements CertificateRepository {
  final CertificateRemoteDataSource _remote;
  CertificateRepositoryImpl(this._remote);

  @override
  Future<Result<Failure, Uint8List>> download(String url) {
    return _remote.download(url);
  }
}
