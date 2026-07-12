import 'dart:convert';

import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/question_entity.dart';
import '../../domain/entities/test_entity.dart';
import '../../domain/entities/test_type.dart';
import '../../domain/repositories/test_repository.dart';
import '../datasources/test_remote_datasource.dart';
import '../models/test_model.dart';

@LazySingleton(as: TestRepository)
class TestRepositoryImpl implements TestRepository {
  final TestRemoteDataSource _remote;
  TestRepositoryImpl(this._remote);

  @override
  Future<Result<Failure, List<TestEntity>>> getTests(String voucherCode) async {
    final result = await _remote.getTests(voucherCode);

    return result.fold(Err.new, (envelope) {
      if (envelope['status'] != 'ok') {
        return Err(
          ServerFailure(
            envelope['message'] as String? ?? 'Tes tidak tersedia saat ini.',
          ),
        );
      }

      final data = envelope['data'] as Map<String, dynamic>? ?? const {};
      final tests = data.entries
          .map(
            (e) => TestModel.fromJson(
              e.key,
              e.value as Map<String, dynamic>,
            ).toEntity(),
          )
          .toList();

      return Ok(tests);
    });
  }

  @override
  Future<Result<Failure, void>> saveTestAnswer({
    required QuestionEntity question,
    required List<String> answerIds,
    required String voucherCode,
    String? subId,
  }) async {
    final body = jsonEncode(
      _buildAnswerBody(question, answerIds, voucherCode, subId),
    );
    final result = await _remote.saveTestAnswer(body);

    return result.fold(Err.new, (envelope) {
      if (envelope['status'] != 'ok') {
        return Err(
          ServerFailure(
            envelope['message'] as String? ?? 'Gagal menyimpan jawaban.',
          ),
        );
      }
      return const Ok(null);
    });
  }

  /// Same field names/shape as the old app's `QuestionMapper.toJson` —
  /// verified by reading it in full, not guessed.
  Map<String, dynamic> _buildAnswerBody(
    QuestionEntity question,
    List<String> answerIds,
    String voucherCode,
    String? subId,
  ) {
    return switch (question.testType) {
      TestType.pengetahuan => {
        'kode_voucher': voucherCode,
        'pengetahuan_umums_id': question.id,
        if (subId != null) 'pengetahuan_umum_subs_id': subId,
        'jawaban_pengetahuan_umum_id': answerIds,
      },
      TestType.psikologi => {
        'kode_voucher': voucherCode,
        'psikologis_id': question.id,
        'jawaban_psikologis_id': answerIds,
      },
    };
  }
}
