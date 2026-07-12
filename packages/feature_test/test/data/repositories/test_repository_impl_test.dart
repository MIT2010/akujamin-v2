import 'dart:convert';

import 'package:core/core.dart';
import 'package:feature_test/feature_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTestRemoteDataSource extends Mock implements TestRemoteDataSource {}

void main() {
  late _MockTestRemoteDataSource remote;
  late TestRepositoryImpl repository;

  setUp(() {
    remote = _MockTestRemoteDataSource();
    repository = TestRepositoryImpl(remote);
  });

  group('TestRepositoryImpl.getTests', () {
    test('maps the envelope into a list of TestEntity on status: ok', () async {
      when(() => remote.getTests('VOUCHER1')).thenAnswer(
        (_) async => Ok(<String, dynamic>{
          'status': 'ok',
          'data': {
            'Tes Kepribadian': {
              'bab': {
                'Bab 1': {
                  'soal': {
                    'Apakah kamu setuju?': {'qid': 'Q1'},
                  },
                },
              },
            },
          },
        }),
      );

      final result = await repository.getTests('VOUCHER1');

      expect(result.isOk, isTrue);
      final tests = (result as Ok<Failure, List<TestEntity>>).value;
      expect(tests, hasLength(1));
      expect(tests.first.name, 'Tes Kepribadian');
      expect(tests.first.sections.single.questions.single.id, 'Q1');
    });

    test('returns Err when the envelope status is not ok', () async {
      when(() => remote.getTests(any())).thenAnswer(
        (_) async => Ok(<String, dynamic>{
          'status': 'error',
          'message': 'Voucher tidak valid',
        }),
      );

      final result = await repository.getTests('BAD');

      expect(result.isErr, isTrue);
      expect(
        (result as Err<Failure, List<TestEntity>>).failure.message,
        'Voucher tidak valid',
      );
    });

    test('propagates a datasource failure as-is', () async {
      when(
        () => remote.getTests(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure()));

      final result = await repository.getTests('VOUCHER1');

      expect(result.isErr, isTrue);
      expect(
        (result as Err<Failure, List<TestEntity>>).failure,
        isA<NetworkFailure>(),
      );
    });
  });

  group('TestRepositoryImpl.saveTestAnswer', () {
    const pengetahuanQuestion = QuestionEntity(
      id: 'Q1',
      text: 'x',
      testType: TestType.pengetahuan,
      showQuestion: true,
    );

    const psikologiQuestion = QuestionEntity(
      id: 'Q2',
      text: 'x',
      testType: TestType.psikologi,
      showQuestion: true,
    );

    test('builds a pengetahuan body with pengetahuan_umums_id/'
        'jawaban_pengetahuan_umum_id, same field names as the old app\'s '
        'QuestionMapper', () async {
      String? sentBody;
      when(() => remote.saveTestAnswer(any())).thenAnswer((invocation) async {
        sentBody = invocation.positionalArguments.single as String;
        return Ok(<String, dynamic>{'status': 'ok'});
      });

      final result = await repository.saveTestAnswer(
        question: pengetahuanQuestion,
        answerIds: ['A1', 'A2'],
        voucherCode: 'VOUCHER1',
      );

      expect(result.isOk, isTrue);
      final body = jsonDecode(sentBody!) as Map<String, dynamic>;
      expect(body['kode_voucher'], 'VOUCHER1');
      expect(body['pengetahuan_umums_id'], 'Q1');
      expect(body['jawaban_pengetahuan_umum_id'], ['A1', 'A2']);
      expect(body.containsKey('pengetahuan_umum_subs_id'), isFalse);
    });

    test(
      'includes pengetahuan_umum_subs_id only when subId is given',
      () async {
        String? sentBody;
        when(() => remote.saveTestAnswer(any())).thenAnswer((invocation) async {
          sentBody = invocation.positionalArguments.single as String;
          return Ok(<String, dynamic>{'status': 'ok'});
        });

        await repository.saveTestAnswer(
          question: pengetahuanQuestion,
          answerIds: ['A1'],
          voucherCode: 'VOUCHER1',
          subId: 'S1',
        );

        final body = jsonDecode(sentBody!) as Map<String, dynamic>;
        expect(body['pengetahuan_umum_subs_id'], 'S1');
      },
    );

    test(
      'builds a psikologi body with psikologis_id/jawaban_psikologis_id',
      () async {
        String? sentBody;
        when(() => remote.saveTestAnswer(any())).thenAnswer((invocation) async {
          sentBody = invocation.positionalArguments.single as String;
          return Ok(<String, dynamic>{'status': 'ok'});
        });

        await repository.saveTestAnswer(
          question: psikologiQuestion,
          answerIds: ['A1'],
          voucherCode: 'VOUCHER1',
        );

        final body = jsonDecode(sentBody!) as Map<String, dynamic>;
        expect(body['psikologis_id'], 'Q2');
        expect(body['jawaban_psikologis_id'], ['A1']);
        expect(body.containsKey('pengetahuan_umums_id'), isFalse);
      },
    );

    test('returns Err when the envelope status is not ok', () async {
      when(() => remote.saveTestAnswer(any())).thenAnswer(
        (_) async => Ok(<String, dynamic>{
          'status': 'error',
          'message': 'Gagal menyimpan',
        }),
      );

      final result = await repository.saveTestAnswer(
        question: pengetahuanQuestion,
        answerIds: ['A1'],
        voucherCode: 'VOUCHER1',
      );

      expect(result.isErr, isTrue);
      expect((result as Err<Failure, void>).failure.message, 'Gagal menyimpan');
    });
  });
}
