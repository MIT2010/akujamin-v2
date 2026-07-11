import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:feature_counseling/feature_counseling.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCounselingRepository extends Mock implements CounselingRepository {}

void main() {
  late _MockCounselingRepository repository;

  final sessions = [
    CounselingSession(
      id: 1,
      code: 'ABC123',
      psychologist: 'Budi',
      status: 'ongoing',
      createdAt: DateTime(2026, 1, 5),
    ),
  ];

  setUp(() {
    repository = _MockCounselingRepository();
  });

  group('CounselingCubit.getSessions', () {
    blocTest<CounselingCubit, CounselingState>(
      'given the repository resolves a list of sessions',
      setUp: () {
        when(
          () => repository.getSessions(),
        ).thenAnswer((_) async => Ok(sessions));
      },
      build: () => CounselingCubit(repository),
      act: (cubit) => cubit.getSessions(),
      expect: () => [
        const CounselingState.loading(),
        CounselingState.loaded(sessions),
      ],
    );

    blocTest<CounselingCubit, CounselingState>(
      'given the repository fails',
      setUp: () {
        when(() => repository.getSessions()).thenAnswer(
          (_) async =>
              const Err(ServerFailure('Internal error', statusCode: 500)),
        );
      },
      build: () => CounselingCubit(repository),
      act: (cubit) => cubit.getSessions(),
      expect: () => [
        const CounselingState.loading(),
        const CounselingState.error(
          ServerFailure('Internal error', statusCode: 500),
        ),
      ],
    );
  });
}
