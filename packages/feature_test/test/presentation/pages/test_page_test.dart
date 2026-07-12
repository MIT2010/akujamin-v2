import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:feature_test/feature_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockTestCubit extends MockCubit<TestState> implements TestCubit {}

class _MockProctoringCubit extends MockCubit<ProctoringState>
    implements ProctoringCubit {}

void main() {
  late _MockTestCubit testCubit;
  late _MockProctoringCubit proctoringCubit;

  Widget harness() {
    return MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/test/VOUCHER1',
        routes: [
          GoRoute(
            path: '/test/:voucher',
            builder: (context, state) => MultiBlocProvider(
              providers: [
                BlocProvider<TestCubit>.value(value: testCubit),
                BlocProvider<ProctoringCubit>.value(value: proctoringCubit),
              ],
              child: const TestView(),
            ),
          ),
          GoRoute(
            path: '/result',
            builder: (context, state) =>
                const Scaffold(body: Text('result-page')),
          ),
        ],
      ),
    );
  }

  final step = const QuestionStep(
    testId: 'Tes Kepribadian',
    sectionId: 'Bab 1',
    questionId: 'Q1',
  );

  final testEntity = TestEntity(
    name: 'Tes Kepribadian',
    type: TestType.psikologi,
    sections: [
      SectionEntity(
        name: 'Bab 1',
        questions: [
          QuestionEntity(
            id: 'Q1',
            text: 'Apakah kamu setuju?',
            testType: TestType.psikologi,
            showQuestion: true,
            answers: const [
              AnswerEntity(answerId: 'A1', answer: 'Setuju'),
              AnswerEntity(answerId: 'A2', answer: 'Tidak setuju'),
            ],
          ),
        ],
      ),
    ],
  );

  setUp(() {
    testCubit = _MockTestCubit();
    proctoringCubit = _MockProctoringCubit();
    when(
      () => proctoringCubit.state,
    ).thenReturn(const ProctoringState.detecting());
    when(
      () => proctoringCubit.stream,
    ).thenAnswer((_) => const Stream<ProctoringState>.empty());
  });

  testWidgets('shows a spinner while loading', (tester) async {
    when(() => testCubit.state).thenReturn(const TestState());
    when(
      () => testCubit.stream,
    ).thenAnswer((_) => const Stream<TestState>.empty());

    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders the current question and its answer options', (
    tester,
  ) async {
    when(() => testCubit.state).thenReturn(
      TestState(status: TestStatus.doing, tests: [testEntity], steps: [step]),
    );
    when(
      () => testCubit.stream,
    ).thenAnswer((_) => const Stream<TestState>.empty());

    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text('Apakah kamu setuju?'), findsOneWidget);
    expect(find.text('Setuju'), findsOneWidget);
    expect(find.text('Tidak setuju'), findsOneWidget);
  });

  testWidgets('tapping an answer calls TestCubit.selectAnswer', (tester) async {
    when(() => testCubit.state).thenReturn(
      TestState(status: TestStatus.doing, tests: [testEntity], steps: [step]),
    );
    when(
      () => testCubit.stream,
    ).thenAnswer((_) => const Stream<TestState>.empty());
    when(
      () => testCubit.selectAnswer(
        testId: any(named: 'testId'),
        sectionId: any(named: 'sectionId'),
        questionId: any(named: 'questionId'),
        subId: any(named: 'subId'),
        answerId: any(named: 'answerId'),
        isMultiple: any(named: 'isMultiple'),
      ),
    ).thenReturn(null);

    await tester.pumpWidget(harness());
    await tester.pump();
    await tester.tap(find.text('Setuju'));

    verify(
      () => testCubit.selectAnswer(
        testId: 'Tes Kepribadian',
        sectionId: 'Bab 1',
        questionId: 'Q1',
        subId: null,
        answerId: 'A1',
        isMultiple: false,
      ),
    ).called(1);
  });

  testWidgets(
    'a proctoring violation covers the question with the block overlay',
    (tester) async {
      when(() => testCubit.state).thenReturn(
        TestState(status: TestStatus.doing, tests: [testEntity], steps: [step]),
      );
      when(
        () => testCubit.stream,
      ).thenAnswer((_) => const Stream<TestState>.empty());
      when(() => proctoringCubit.state).thenReturn(
        const ProctoringState.detecting(
          status: AttentionStatus.noFace,
          isViolation: true,
        ),
      );

      await tester.pumpWidget(harness());
      await tester.pump();

      expect(find.text('Wajah tidak terdeteksi'), findsOneWidget);
    },
  );

  testWidgets('an error status shows the failure message as a snackbar', (
    tester,
  ) async {
    whenListen(
      testCubit,
      Stream.fromIterable([
        TestState(
          status: TestStatus.error,
          tests: [testEntity],
          steps: [step],
          error: const ValidationFailure('Jawaban tidak boleh kosong.'),
        ),
      ]),
      initialState: TestState(
        status: TestStatus.doing,
        tests: [testEntity],
        steps: [step],
      ),
    );

    await tester.pumpWidget(harness());
    await tester.pump();
    await tester.pump();

    expect(find.text('Jawaban tidak boleh kosong.'), findsOneWidget);
  });

  testWidgets('a done status navigates to the result page', (tester) async {
    whenListen(
      testCubit,
      Stream.fromIterable([
        TestState(status: TestStatus.done, tests: [testEntity], steps: [step]),
      ]),
      initialState: TestState(
        status: TestStatus.doing,
        tests: [testEntity],
        steps: [step],
      ),
    );

    await tester.pumpWidget(harness());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('result-page'), findsOneWidget);
  });
}
