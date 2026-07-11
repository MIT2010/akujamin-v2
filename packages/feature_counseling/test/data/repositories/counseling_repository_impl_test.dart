import 'package:core/core.dart';
import 'package:feature_counseling/feature_counseling.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCounselingRemoteDataSource extends Mock
    implements CounselingRemoteDataSource {}

void main() {
  late _MockCounselingRemoteDataSource remote;
  late CounselingRepositoryImpl repository;

  setUp(() {
    remote = _MockCounselingRemoteDataSource();
    repository = CounselingRepositoryImpl(remote);
  });

  group('CounselingRepositoryImpl.getSessions', () {
    test('returns Ok with the mapped entities when status is ok', () async {
      when(() => remote.getSessions()).thenAnswer(
        (_) async => Ok(<String, dynamic>{
          'status': 'ok',
          'message': 'success',
          // Deliberately 'data', not 'datas' — the real envelope key for
          // this endpoint, confirmed by reading the old app's repository.
          'data': [
            {
              'conversation_id': 1,
              'kode_voucher': 'ABC123',
              'psikolog_name': 'Budi',
              'status': 'ongoing',
              'tanggal': '2026-01-05T00:00:00.000Z',
            },
          ],
        }),
      );

      final result = await repository.getSessions();

      expect(result.isOk, isTrue);
      final sessions = (result as Ok<Failure, List<CounselingSession>>).value;
      expect(sessions, hasLength(1));
      expect(sessions.first.id, 1);
      expect(sessions.first.code, 'ABC123');
      expect(sessions.first.psychologist, 'Budi');
    });

    test('returns Err when the envelope status is not ok', () async {
      when(() => remote.getSessions()).thenAnswer(
        (_) async => Ok(<String, dynamic>{
          'status': 'error',
          'message': 'Sesi tidak ditemukan',
        }),
      );

      final result = await repository.getSessions();

      expect(result.isErr, isTrue);
      final failure = (result as Err<Failure, List<CounselingSession>>).failure;
      expect(failure, isA<ServerFailure>());
      expect(failure.message, 'Sesi tidak ditemukan');
    });

    test('returns Err on a server failure from the datasource', () async {
      when(() => remote.getSessions()).thenAnswer(
        (_) async =>
            const Err(ServerFailure('Internal error', statusCode: 500)),
      );

      final result = await repository.getSessions();

      expect(result.isErr, isTrue);
      expect(
        (result as Err<Failure, List<CounselingSession>>).failure,
        isA<ServerFailure>(),
      );
    });
  });
}
