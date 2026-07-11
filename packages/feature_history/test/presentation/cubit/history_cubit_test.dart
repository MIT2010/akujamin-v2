import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:feature_history/feature_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockHistoryRepository extends Mock implements HistoryRepository {}

void main() {
  late _MockHistoryRepository repository;

  final items = [
    TestHistoryItem(
      code: 'ABC123',
      job: 'Perawat',
      destinationCountry: 'Jepang',
      status: 'Lulus',
      institution: 'Lembaga A',
      psychologist: 'Budi',
      testAttempt: '1',
      testResult: 'Baik',
      createdAt: DateTime(2026, 1, 5),
      certificateUrl: 'https://example.com/cert.pdf',
    ),
  ];

  setUp(() {
    repository = _MockHistoryRepository();
  });

  group('HistoryCubit.getHistory', () {
    blocTest<HistoryCubit, HistoryState>(
      'given the repository resolves a list of history items',
      setUp: () {
        when(() => repository.getHistory()).thenAnswer((_) async => Ok(items));
      },
      build: () => HistoryCubit(repository),
      act: (cubit) => cubit.getHistory(),
      expect: () => [const HistoryState.loading(), HistoryState.loaded(items)],
    );

    blocTest<HistoryCubit, HistoryState>(
      'given the repository fails',
      setUp: () {
        when(() => repository.getHistory()).thenAnswer(
          (_) async =>
              const Err(ServerFailure('Internal error', statusCode: 500)),
        );
      },
      build: () => HistoryCubit(repository),
      act: (cubit) => cubit.getHistory(),
      expect: () => [
        const HistoryState.loading(),
        const HistoryState.error(
          ServerFailure('Internal error', statusCode: 500),
        ),
      ],
    );
  });
}
