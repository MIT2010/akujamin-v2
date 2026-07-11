import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_history/feature_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockHistoryCubit extends MockCubit<HistoryState>
    implements HistoryCubit {}

void main() {
  late _MockHistoryCubit historyCubit;

  Widget harness(_MockHistoryCubit historyCubit) {
    return MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/history',
        routes: [
          GoRoute(
            path: '/history',
            builder: (context, state) => BlocProvider<HistoryCubit>.value(
              value: historyCubit,
              child: const HistoryView(),
            ),
          ),
          GoRoute(
            path: '/certificate',
            builder: (context, state) => Scaffold(
              body: Text(
                'certificate-page:${state.uri.queryParameters['url']}',
              ),
            ),
          ),
        ],
      ),
    );
  }

  setUp(() {
    historyCubit = _MockHistoryCubit();
  });

  final passedItem = TestHistoryItem(
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
  );

  testWidgets('shows a spinner while loading', (tester) async {
    when(() => historyCubit.state).thenReturn(const HistoryState.loading());

    await tester.pumpWidget(harness(historyCubit));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the error message and a retry button', (tester) async {
    when(() => historyCubit.state).thenReturn(
      const HistoryState.error(ServerFailure('Gagal memuat', statusCode: 500)),
    );
    when(() => historyCubit.getHistory()).thenAnswer((_) async {});

    await tester.pumpWidget(harness(historyCubit));

    expect(find.text('Gagal memuat'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    verify(() => historyCubit.getHistory()).called(1);
  });

  testWidgets('shows the empty state and offers "Mulai Tes" as a placeholder', (
    tester,
  ) async {
    when(() => historyCubit.state).thenReturn(const HistoryState.loaded([]));

    await tester.pumpWidget(harness(historyCubit));

    expect(find.text('Belum ada tes'), findsOneWidget);

    await tester.tap(find.text('Mulai Tes'));
    await tester.pumpAndSettle();

    expect(
      find.text('Fitur ini belum tersedia. Coba lagi nanti.'),
      findsOneWidget,
    );
  });

  testWidgets('shows all fields for a history item', (tester) async {
    when(
      () => historyCubit.state,
    ).thenReturn(HistoryState.loaded([passedItem]));

    await tester.pumpWidget(harness(historyCubit));

    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('Lembaga A'), findsOneWidget);
    expect(find.text('Budi'), findsOneWidget);
    expect(find.text('Jepang'), findsOneWidget);
    expect(find.text('Perawat'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Lulus'), findsOneWidget);
    expect(find.text('Baik'), findsOneWidget);
  });

  testWidgets('"Lihat Sertifikat" navigates to /certificate with the url', (
    tester,
  ) async {
    when(
      () => historyCubit.state,
    ).thenReturn(HistoryState.loaded([passedItem]));

    await tester.pumpWidget(harness(historyCubit));
    await tester.tap(find.text('Lihat Sertifikat'));
    await tester.pumpAndSettle();

    expect(
      find.text('certificate-page:https://example.com/cert.pdf'),
      findsOneWidget,
    );
  });

  testWidgets(
    '"Lanjutkan Tes" for an in-progress test shows the placeholder dialog',
    (tester) async {
      final item = passedItem.copyWith(status: 'Sedang Tes');
      when(() => historyCubit.state).thenReturn(HistoryState.loaded([item]));

      await tester.pumpWidget(harness(historyCubit));
      await tester.tap(find.text('Lanjutkan Tes'));
      await tester.pumpAndSettle();

      expect(
        find.text('Fitur ini belum tersedia. Coba lagi nanti.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '"Konseling" for a counseling item shows the placeholder dialog',
    (tester) async {
      final item = passedItem.copyWith(status: 'Konseling');
      when(() => historyCubit.state).thenReturn(HistoryState.loaded([item]));

      await tester.pumpWidget(harness(historyCubit));
      // Two matches: the "Status Ujian" info row's value and the button
      // itself both read "Konseling" for this status — the button is the
      // later one in the tile's Column.
      await tester.tap(find.text('Konseling').last);
      await tester.pumpAndSettle();

      expect(
        find.text('Fitur ini belum tersedia. Coba lagi nanti.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('a finished item with no further action shows no button', (
    tester,
  ) async {
    final item = passedItem.copyWith(status: 'Tidak Lulus');
    when(() => historyCubit.state).thenReturn(HistoryState.loaded([item]));

    await tester.pumpWidget(harness(historyCubit));

    expect(find.byType(AppButton), findsNothing);
  });
}
