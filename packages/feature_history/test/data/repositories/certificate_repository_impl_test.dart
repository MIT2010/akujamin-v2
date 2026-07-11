import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:feature_history/feature_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCertificateRemoteDataSource extends Mock
    implements CertificateRemoteDataSource {}

void main() {
  late _MockCertificateRemoteDataSource remote;
  late CertificateRepositoryImpl repository;

  setUp(() {
    remote = _MockCertificateRemoteDataSource();
    repository = CertificateRepositoryImpl(remote);
  });

  group('CertificateRepositoryImpl.download', () {
    test('passes the url through and returns the datasource bytes', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      when(
        () => remote.download('https://example.com/cert.pdf'),
      ).thenAnswer((_) async => Ok(bytes));

      final result = await repository.download('https://example.com/cert.pdf');

      expect(result.isOk, isTrue);
      expect((result as Ok<Failure, Uint8List>).value, bytes);
      verify(() => remote.download('https://example.com/cert.pdf')).called(1);
    });

    test('passes the datasource failure through unchanged', () async {
      when(
        () => remote.download(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure()));

      final result = await repository.download('https://example.com/cert.pdf');

      expect(result.isErr, isTrue);
      expect(
        (result as Err<Failure, Uint8List>).failure,
        isA<NetworkFailure>(),
      );
    });
  });
}
