import 'package:core/core.dart';

import '../entities/question_entity.dart';
import '../entities/test_entity.dart';

/// No UseCase in front of this (§21/ADR-004) — both old-app usecases
/// (`GetTestsUsecase`/`SaveTestAnswerUsecase`) are thin pass-throughs, same
/// conclusion as `about`/`onboarding`/`history`/`counseling`/`payment`.
///
/// [saveTestAnswer] takes structured parameters, not a pre-built JSON
/// string — unlike the old app's `TestStateCubit`, which built the request
/// body itself (`QuestionMapper.toJson`) and handed the *presentation*
/// layer a wire-format concern. The migrated repository implementation
/// owns that encoding instead, same shape every other repository in this
/// codebase already has (`PaymentRepository.createVoucher(Map<String,
/// String>)`, not a pre-serialized body) — identical wire behavior, better
/// layering.
abstract class TestRepository {
  Future<Result<Failure, List<TestEntity>>> getTests(String voucherCode);

  Future<Result<Failure, void>> saveTestAnswer({
    required QuestionEntity question,
    required List<String> answerIds,
    required String voucherCode,
    String? subId,
  });
}
