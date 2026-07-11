import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared/shared.dart';

class _MockFormInputRemoteDataSource extends Mock
    implements FormInputRemoteDataSource {}

void main() {
  late _MockFormInputRemoteDataSource remote;
  late FormInputRepositoryImpl repository;

  setUp(() {
    remote = _MockFormInputRemoteDataSource();
    repository = FormInputRepositoryImpl(remote);
  });

  group('FormInputRepositoryImpl.getForm', () {
    test('maps a bare JSON array response into entities — this endpoint has '
        'no {status, data} envelope, unlike most others in this codebase, '
        'confirmed against the old app', () async {
      when(() => remote.getForm('/tes/pertanyaan')).thenAnswer(
        (_) async => Ok(<dynamic>[
          {
            'label': 'psikologi',
            'display': 'Psikolog',
            'type': 'select',
            'validate': true,
            'read_only': false,
            'value': [
              {'value': 'Budi', 'kode': '27'},
            ],
          },
          {
            'label': 'tgl_lahir',
            'display': 'Tanggal Lahir',
            'type': 'date',
            'validate': true,
            'read_only': false,
          },
        ]),
      );

      final result = await repository.getForm('/tes/pertanyaan');

      expect(result.isOk, isTrue);
      final fields = (result as Ok<Failure, List<FormInputField>>).value;
      expect(fields, hasLength(2));
      expect(fields.first.label, 'psikologi');
      expect(fields.first.options!.single.value, '27');
      expect(fields.last.isDate, isTrue);
    });

    test('passes an empty schema through as an empty list', () async {
      when(
        () => remote.getForm('/registrasi/profile'),
      ).thenAnswer((_) async => const Ok(<dynamic>[]));

      final result = await repository.getForm('/registrasi/profile');

      expect(result.isOk, isTrue);
      expect((result as Ok<Failure, List<FormInputField>>).value, isEmpty);
    });

    test('propagates a datasource failure as-is', () async {
      when(() => remote.getForm('/tes/pertanyaan')).thenAnswer(
        (_) async =>
            const Err(ServerFailure('Internal error', statusCode: 500)),
      );

      final result = await repository.getForm('/tes/pertanyaan');

      expect(result.isErr, isTrue);
      expect(
        (result as Err<Failure, List<FormInputField>>).failure,
        isA<ServerFailure>(),
      );
    });
  });
}
