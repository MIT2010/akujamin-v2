import 'package:core/core.dart';
import 'package:feature_about/feature_about.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAboutRemoteDataSource extends Mock
    implements AboutRemoteDataSource {}

void main() {
  late _MockAboutRemoteDataSource remote;
  late AboutRepositoryImpl repository;

  setUp(() {
    remote = _MockAboutRemoteDataSource();
    repository = AboutRepositoryImpl(remote);
  });

  group('AboutRepositoryImpl.getAbout', () {
    test('returns Ok with the mapped entities when status is ok', () async {
      when(() => remote.getAbout()).thenAnswer(
        (_) async => Ok(<String, dynamic>{
          'status': 'ok',
          'message': 'success',
          'datas': [
            {'jenis': 'Umum', 'text': 'Ini adalah jawaban umum.'},
            {'jenis': 'Pembayaran', 'text': 'Ini adalah jawaban pembayaran.'},
          ],
        }),
      );

      final result = await repository.getAbout();

      expect(result.isOk, isTrue);
      final items = (result as Ok<Failure, List<About>>).value;
      expect(items, hasLength(2));
      expect(items.first.type, 'Umum');
      expect(items.first.text, 'Ini adalah jawaban umum.');
    });

    test('returns Err when the envelope status is not ok', () async {
      when(() => remote.getAbout()).thenAnswer(
        (_) async => Ok(<String, dynamic>{
          'status': 'error',
          'message': 'FAQ tidak ditemukan',
        }),
      );

      final result = await repository.getAbout();

      expect(result.isErr, isTrue);
      final failure = (result as Err<Failure, List<About>>).failure;
      expect(failure, isA<ServerFailure>());
      expect(failure.message, 'FAQ tidak ditemukan');
    });

    test('returns Err on a server failure from the datasource', () async {
      when(() => remote.getAbout()).thenAnswer(
        (_) async =>
            const Err(ServerFailure('Internal error', statusCode: 500)),
      );

      final result = await repository.getAbout();

      expect(result.isErr, isTrue);
      expect(
        (result as Err<Failure, List<About>>).failure,
        isA<ServerFailure>(),
      );
    });
  });
}
