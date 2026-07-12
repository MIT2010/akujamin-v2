import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:feature_test/feature_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTestRepository extends Mock implements TestRepository {}

/// A controllable fake, not a mock — call counts matter (screenshot
/// lifecycle) more than argument matching, same reasoning as this
/// session's other `_Fake*Gateway`s.
class _FakeScreenshotGateway implements ScreenshotGateway {
  int disableCalls = 0;
  int enableCalls = 0;

  @override
  Future<void> disable() async => disableCalls++;

  @override
  Future<void> enable() async => enableCalls++;
}

void main() {
  late _MockTestRepository repository;
  late _FakeScreenshotGateway screenshotGateway;

  setUpAll(() {
    registerFallbackValue(
      const QuestionEntity(
        text: 'x',
        testType: TestType.pengetahuan,
        showQuestion: true,
      ),
    );
  });

  setUp(() {
    repository = _MockTestRepository();
    screenshotGateway = _FakeScreenshotGateway();
  });

  TestCubit build() => TestCubit(repository, screenshotGateway);

  final singleQuestionTest = TestEntity(
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

  group('TestCubit — screenshot lifecycle (real fix for finding #8)', () {
    test('disables screenshot protection exactly once at construction', () {
      build();

      expect(screenshotGateway.disableCalls, 1);
      expect(screenshotGateway.enableCalls, 0);
    });

    test(
      're-enables screenshot protection on close, on every exit path',
      () async {
        final cubit = build();

        await cubit.close();

        expect(screenshotGateway.enableCalls, 1);
      },
    );
  });

  group('TestCubit.getTests', () {
    blocTest<TestCubit, TestState>(
      'builds a linear step list and moves to doing on success',
      build: build,
      setUp: () {
        when(
          () => repository.getTests('VOUCHER1'),
        ).thenAnswer((_) async => Ok([singleQuestionTest]));
      },
      act: (cubit) => cubit.getTests('VOUCHER1'),
      expect: () => [
        isA<TestState>().having((s) => s.status, 'status', TestStatus.loading),
        isA<TestState>()
            .having((s) => s.status, 'status', TestStatus.doing)
            .having((s) => s.steps, 'steps', hasLength(1))
            .having((s) => s.tests, 'tests', hasLength(1)),
      ],
    );

    blocTest<TestCubit, TestState>(
      'moves to failed when the repository fails',
      build: build,
      setUp: () {
        when(
          () => repository.getTests(any()),
        ).thenAnswer((_) async => const Err(NetworkFailure()));
      },
      act: (cubit) => cubit.getTests('VOUCHER1'),
      expect: () => [
        isA<TestState>().having((s) => s.status, 'status', TestStatus.loading),
        isA<TestState>()
            .having((s) => s.status, 'status', TestStatus.failed)
            .having((s) => s.error, 'error', isA<NetworkFailure>()),
      ],
    );

    blocTest<TestCubit, TestState>(
      'moves to failed when every question is missing an id and no step '
      'can be built at all — the defensive skip has to lead somewhere '
      'explicit, not a silently empty test',
      build: build,
      setUp: () {
        when(() => repository.getTests(any())).thenAnswer(
          (_) async => Ok([
            TestEntity(
              name: 'x',
              type: TestType.psikologi,
              sections: [
                SectionEntity(
                  name: 'Bab 1',
                  questions: [
                    QuestionEntity(
                      text: 'no id',
                      testType: TestType.psikologi,
                      showQuestion: true,
                    ),
                  ],
                ),
              ],
            ),
          ]),
        );
      },
      act: (cubit) => cubit.getTests('VOUCHER1'),
      expect: () => [
        isA<TestState>().having((s) => s.status, 'status', TestStatus.loading),
        isA<TestState>().having((s) => s.status, 'status', TestStatus.failed),
      ],
    );

    blocTest<TestCubit, TestState>(
      'flattens sub_items into one step per sub-item',
      build: build,
      setUp: () {
        when(() => repository.getTests(any())).thenAnswer(
          (_) async => Ok([
            TestEntity(
              name: 'x',
              type: TestType.psikologi,
              sections: [
                SectionEntity(
                  name: 'Bab 1',
                  questions: [
                    QuestionEntity(
                      id: 'Q1',
                      text: 'x',
                      testType: TestType.psikologi,
                      showQuestion: true,
                      subItems: const [
                        SubItemEntity(subId: 'S1', text: 'a', answers: []),
                        SubItemEntity(subId: 'S2', text: 'b', answers: []),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ]),
        );
      },
      act: (cubit) => cubit.getTests('VOUCHER1'),
      verify: (cubit) {
        expect(cubit.state.steps, hasLength(2));
        expect(cubit.state.steps.map((s) => s.subId), ['S1', 'S2']);
      },
    );
  });

  group('TestCubit.selectAnswer', () {
    blocTest<TestCubit, TestState>(
      'a single-choice question replaces the previous selection',
      build: build,
      act: (cubit) {
        cubit.selectAnswer(
          testId: 'T',
          sectionId: 'S',
          questionId: 'Q1',
          answerId: 'A1',
          isMultiple: false,
        );
        cubit.selectAnswer(
          testId: 'T',
          sectionId: 'S',
          questionId: 'Q1',
          answerId: 'A2',
          isMultiple: false,
        );
      },
      verify: (cubit) {
        expect(cubit.state.answers['T_S_Q1'], ['A2']);
      },
    );

    blocTest<TestCubit, TestState>(
      'a multiple-choice question toggles independently, tapping the same '
      'answer twice deselects it',
      build: build,
      act: (cubit) {
        cubit.selectAnswer(
          testId: 'T',
          sectionId: 'S',
          questionId: 'Q1',
          answerId: 'A1',
          isMultiple: true,
        );
        cubit.selectAnswer(
          testId: 'T',
          sectionId: 'S',
          questionId: 'Q1',
          answerId: 'A2',
          isMultiple: true,
        );
        cubit.selectAnswer(
          testId: 'T',
          sectionId: 'S',
          questionId: 'Q1',
          answerId: 'A1',
          isMultiple: true,
        );
      },
      verify: (cubit) {
        expect(cubit.state.answers['T_S_Q1'], ['A2']);
      },
    );
  });

  group('TestCubit.nextStep — approved fix: cubit-level answer validation '
      '(second, independent layer)', () {
    blocTest<TestCubit, TestState>(
      'refuses to submit when no answer is selected — the repository is '
      'never called at all, not just rejected after the fact',
      build: build,
      seed: () => TestState(
        status: TestStatus.doing,
        tests: [singleQuestionTest],
        steps: [
          const QuestionStep(
            testId: 'Tes Kepribadian',
            sectionId: 'Bab 1',
            questionId: 'Q1',
          ),
        ],
      ),
      act: (cubit) => cubit.nextStep(
        const QuestionStep(
          testId: 'Tes Kepribadian',
          sectionId: 'Bab 1',
          questionId: 'Q1',
        ),
      ),
      expect: () => [
        isA<TestState>().having((s) => s.status, 'status', TestStatus.sending),
        isA<TestState>()
            .having((s) => s.status, 'status', TestStatus.error)
            .having((s) => s.error, 'error', isA<ValidationFailure>())
            .having((s) => s.isSubmitting, 'isSubmitting', isFalse),
      ],
      verify: (_) {
        verifyNever(
          () => repository.saveTestAnswer(
            question: any(named: 'question'),
            answerIds: any(named: 'answerIds'),
            voucherCode: any(named: 'voucherCode'),
            subId: any(named: 'subId'),
          ),
        );
      },
    );
  });

  group('TestCubit.nextStep — normal progression', () {
    final twoQuestionTest = TestEntity(
      name: 'Tes Kepribadian',
      type: TestType.psikologi,
      sections: [
        SectionEntity(
          name: 'Bab 1',
          questions: [
            QuestionEntity(
              id: 'Q1',
              text: 'x',
              testType: TestType.psikologi,
              showQuestion: true,
              answers: const [AnswerEntity(answerId: 'A1', answer: 'Ya')],
            ),
            QuestionEntity(
              id: 'Q2',
              text: 'y',
              testType: TestType.psikologi,
              showQuestion: true,
              answers: const [AnswerEntity(answerId: 'A2', answer: 'Ya')],
            ),
          ],
        ),
      ],
    );

    const step1 = QuestionStep(
      testId: 'Tes Kepribadian',
      sectionId: 'Bab 1',
      questionId: 'Q1',
    );
    const step2 = QuestionStep(
      testId: 'Tes Kepribadian',
      sectionId: 'Bab 1',
      questionId: 'Q2',
    );

    blocTest<TestCubit, TestState>(
      'advances currentStepIndex when the next step is in the same '
      'test/section',
      build: build,
      setUp: () {
        when(
          () => repository.getTests('VOUCHER1'),
        ).thenAnswer((_) async => Ok([twoQuestionTest]));
        when(
          () => repository.saveTestAnswer(
            question: any(named: 'question'),
            answerIds: any(named: 'answerIds'),
            voucherCode: any(named: 'voucherCode'),
            subId: any(named: 'subId'),
          ),
        ).thenAnswer((_) async => const Ok(null));
      },
      // `_voucherCode` is only set by `getTests`, exactly like the old
      // app's `_currentVoucher` — calling it first (instead of `seed:`)
      // is what real usage does anyway, `nextStep` is never reachable
      // before a test has loaded.
      act: (cubit) async {
        await cubit.getTests('VOUCHER1');
        cubit.selectAnswer(
          testId: 'Tes Kepribadian',
          sectionId: 'Bab 1',
          questionId: 'Q1',
          answerId: 'A1',
          isMultiple: false,
        );
        await cubit.nextStep(step1);
      },
      verify: (cubit) {
        expect(cubit.state.currentStepIndex, 1);
        expect(cubit.state.showPopup, isFalse);
      },
    );

    blocTest<TestCubit, TestState>(
      'shows the non-dismissible popup and stages pendingStepIndex on the '
      'last step instead of advancing currentStepIndex',
      build: build,
      setUp: () {
        when(
          () => repository.getTests('VOUCHER1'),
        ).thenAnswer((_) async => Ok([twoQuestionTest]));
        when(
          () => repository.saveTestAnswer(
            question: any(named: 'question'),
            answerIds: any(named: 'answerIds'),
            voucherCode: any(named: 'voucherCode'),
            subId: any(named: 'subId'),
          ),
        ).thenAnswer((_) async => const Ok(null));
      },
      // Must actually walk from step1 to step2 through the cubit itself
      // first — `nextStep`'s "is this the last step" check reads
      // `state.currentStepIndex`, not the step passed in, so jumping
      // straight to `nextStep(step2)` without first advancing past step1
      // would still see currentStepIndex 0 and never reach the isLastStep
      // branch this test is about.
      act: (cubit) async {
        await cubit.getTests('VOUCHER1');
        cubit.selectAnswer(
          testId: 'Tes Kepribadian',
          sectionId: 'Bab 1',
          questionId: 'Q1',
          answerId: 'A1',
          isMultiple: false,
        );
        await cubit.nextStep(step1);
        cubit.selectAnswer(
          testId: 'Tes Kepribadian',
          sectionId: 'Bab 1',
          questionId: 'Q2',
          answerId: 'A2',
          isMultiple: false,
        );
        await cubit.nextStep(step2);
      },
      verify: (cubit) {
        expect(cubit.state.currentStepIndex, 1);
        expect(cubit.state.showPopup, isTrue);
        expect(cubit.state.isLast, isTrue);
      },
    );

    blocTest<TestCubit, TestState>(
      'a repository failure surfaces as an error state and never advances',
      build: build,
      setUp: () {
        when(
          () => repository.getTests('VOUCHER1'),
        ).thenAnswer((_) async => Ok([twoQuestionTest]));
        when(
          () => repository.saveTestAnswer(
            question: any(named: 'question'),
            answerIds: any(named: 'answerIds'),
            voucherCode: any(named: 'voucherCode'),
            subId: any(named: 'subId'),
          ),
        ).thenAnswer((_) async => const Err(ServerFailure('Gagal')));
      },
      act: (cubit) async {
        await cubit.getTests('VOUCHER1');
        cubit.selectAnswer(
          testId: 'Tes Kepribadian',
          sectionId: 'Bab 1',
          questionId: 'Q1',
          answerId: 'A1',
          isMultiple: false,
        );
        await cubit.nextStep(step1);
      },
      verify: (cubit) {
        expect(cubit.state.status, TestStatus.error);
        expect(cubit.state.currentStepIndex, 0);
      },
    );
  });

  group('TestCubit.closePopup', () {
    blocTest<TestCubit, TestState>(
      'moves to done when the popup was for the last step',
      build: build,
      seed: () => const TestState(
        status: TestStatus.doing,
        showPopup: true,
        isLast: true,
      ),
      act: (cubit) => cubit.closePopup(),
      expect: () => [
        isA<TestState>().having((s) => s.status, 'status', TestStatus.done),
      ],
    );

    blocTest<TestCubit, TestState>(
      'advances to pendingStepIndex and resets popup state otherwise',
      build: build,
      seed: () => TestState(
        status: TestStatus.doing,
        showPopup: true,
        pendingStepIndex: 1,
        steps: const [
          QuestionStep(testId: 'T1', sectionId: 'S1', questionId: 'Q1'),
          QuestionStep(
            testId: 'T2',
            sectionId: 'S2',
            questionId: 'Q1',
            hasTestIntro: true,
          ),
        ],
      ),
      act: (cubit) => cubit.closePopup(),
      verify: (cubit) {
        expect(cubit.state.currentStepIndex, 1);
        expect(cubit.state.showPopup, isFalse);
        expect(cubit.state.pendingStepIndex, isNull);
        expect(cubit.state.showIntro, isTrue);
      },
    );
  });

  group('TestCubit.dismissIntro / dismissInstruction', () {
    blocTest<TestCubit, TestState>(
      'dismissIntro clears showIntro only',
      build: build,
      seed: () => const TestState(showIntro: true, showInstruction: true),
      act: (cubit) => cubit.dismissIntro(),
      verify: (cubit) {
        expect(cubit.state.showIntro, isFalse);
        expect(cubit.state.showInstruction, isTrue);
      },
    );

    blocTest<TestCubit, TestState>(
      'dismissInstruction clears showInstruction only',
      build: build,
      seed: () => const TestState(showIntro: true, showInstruction: true),
      act: (cubit) => cubit.dismissInstruction(),
      verify: (cubit) {
        expect(cubit.state.showIntro, isTrue);
        expect(cubit.state.showInstruction, isFalse);
      },
    );
  });
}
