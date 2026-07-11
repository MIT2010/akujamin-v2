import 'package:core/core.dart';
import 'package:feature_history/feature_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockHistoryRemoteDataSource extends Mock
    implements HistoryRemoteDataSource {}

void main() {
  late _MockHistoryRemoteDataSource remote;
  late HistoryRepositoryImpl repository;

  setUp(() {
    remote = _MockHistoryRemoteDataSource();
    repository = HistoryRepositoryImpl(remote);
  });

  group('HistoryRepositoryImpl.getHistory', () {
    test('returns Ok with the mapped entities when status is ok', () async {
      when(() => remote.getHistory()).thenAnswer(
        (_) async => Ok(<String, dynamic>{
          'status': 'ok',
          'message': 'success',
          'datas': [
            {
              'kode_voucher': 'ABC123',
              'jenis_pekerjaan': 'Perawat',
              'negara_tujuan': 'Jepang',
              'status_ujian': 'Lulus',
              'nama_lembaga': 'Lembaga A',
              'nama_psikolog': 'Budi',
              'ujian_ke': '1',
              'hasil_tes': 'Baik',
              'tgl_regis': '2026-01-05T00:00:00.000Z',
              'sertifikat': 'https://example.com/cert.pdf',
            },
          ],
        }),
      );

      final result = await repository.getHistory();

      expect(result.isOk, isTrue);
      final items = (result as Ok<Failure, List<TestHistoryItem>>).value;
      expect(items, hasLength(1));
      expect(items.first.code, 'ABC123');
      expect(items.first.psychologist, 'Budi');
      expect(items.first.certificateUrl, 'https://example.com/cert.pdf');
    });

    test('returns Err when the envelope status is not ok', () async {
      when(() => remote.getHistory()).thenAnswer(
        (_) async => Ok(<String, dynamic>{
          'status': 'error',
          'message': 'Riwayat tidak ditemukan',
        }),
      );

      final result = await repository.getHistory();

      expect(result.isErr, isTrue);
      final failure = (result as Err<Failure, List<TestHistoryItem>>).failure;
      expect(failure, isA<ServerFailure>());
      expect(failure.message, 'Riwayat tidak ditemukan');
    });

    test('returns Err on a server failure from the datasource', () async {
      when(() => remote.getHistory()).thenAnswer(
        (_) async =>
            const Err(ServerFailure('Internal error', statusCode: 500)),
      );

      final result = await repository.getHistory();

      expect(result.isErr, isTrue);
      expect(
        (result as Err<Failure, List<TestHistoryItem>>).failure,
        isA<ServerFailure>(),
      );
    });
  });
}
