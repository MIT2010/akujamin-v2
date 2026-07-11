import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:feature_counseling/feature_counseling.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockCounselingCubit extends MockCubit<CounselingState>
    implements CounselingCubit {}

void main() {
  late _MockCounselingCubit cubit;

  Widget harness(_MockCounselingCubit cubit) {
    return MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/counseling',
        routes: [
          GoRoute(
            path: '/counseling',
            builder: (context, state) => BlocProvider<CounselingCubit>.value(
              value: cubit,
              child: const CounselingListView(),
            ),
          ),
          GoRoute(
            path: '/chat/:code',
            builder: (context, state) => Scaffold(
              body: Text(
                'chat-page:${state.pathParameters['code']}:'
                '${state.uri.queryParameters['psychologist']}',
              ),
            ),
          ),
        ],
      ),
    );
  }

  setUp(() {
    cubit = _MockCounselingCubit();
  });

  final ongoingSession = CounselingSession(
    id: 1,
    code: 'ABC123',
    psychologist: 'Budi',
    status: 'ongoing',
    createdAt: DateTime(2026, 1, 5),
  );

  testWidgets('shows a spinner while loading', (tester) async {
    when(() => cubit.state).thenReturn(const CounselingState.loading());

    await tester.pumpWidget(harness(cubit));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the error message and a retry button', (tester) async {
    when(() => cubit.state).thenReturn(
      const CounselingState.error(
        ServerFailure('Gagal memuat', statusCode: 500),
      ),
    );
    when(() => cubit.getSessions()).thenAnswer((_) async {});

    await tester.pumpWidget(harness(cubit));

    expect(find.text('Gagal memuat'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    verify(() => cubit.getSessions()).called(1);
  });

  testWidgets('shows the empty state', (tester) async {
    when(() => cubit.state).thenReturn(const CounselingState.loaded([]));

    await tester.pumpWidget(harness(cubit));

    expect(find.text('Belum ada sesi konseling'), findsOneWidget);
  });

  testWidgets('shows session fields and navigates to the real chat page', (
    tester,
  ) async {
    when(
      () => cubit.state,
    ).thenReturn(CounselingState.loaded([ongoingSession]));

    await tester.pumpWidget(harness(cubit));

    expect(find.text('Budi'), findsOneWidget);
    expect(find.text('Status: ongoing'), findsOneWidget);

    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    expect(find.text('chat-page:ABC123:Budi'), findsOneWidget);
  });

  testWidgets('disables the Chat button for a finished session', (
    tester,
  ) async {
    final finished = ongoingSession.copyWith(status: 'finished');
    when(() => cubit.state).thenReturn(CounselingState.loaded([finished]));

    await tester.pumpWidget(harness(cubit));

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Chat'),
    );
    expect(button.onPressed, isNull);
  });
}
