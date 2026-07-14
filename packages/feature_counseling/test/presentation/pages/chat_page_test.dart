import 'package:authentication/authentication.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:feature_counseling/feature_counseling.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockChatCubit extends MockCubit<ChatState> implements ChatCubit {}

class _MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

void main() {
  late _MockChatCubit chatCubit;
  late _MockAuthCubit authCubit;

  const user = User(id: 'user-1', email: 'a@example.com', role: 'user');

  // Real GoRouter, not a bare MaterialApp — ChatView's "Mulai Tes Kedua"
  // button reads GoRouterState.of(context).pathParameters['code'] (same
  // pattern as the existing "Coba lagi" retry button), so it needs an
  // actual route to resolve that from. Matches feature_history's own
  // history_page_test.dart harness shape for the same reason.
  Widget harness(_MockChatCubit chatCubit, _MockAuthCubit authCubit) {
    return MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/chat/ABC123',
        routes: [
          GoRoute(
            path: '/chat/:code',
            builder: (context, state) => MultiBlocProvider(
              providers: [
                BlocProvider<ChatCubit>.value(value: chatCubit),
                BlocProvider<AuthCubit>.value(value: authCubit),
              ],
              child: const ChatView(psychologist: 'Budi'),
            ),
          ),
          GoRoute(
            path: '/test/:code',
            builder: (context, state) => Scaffold(
              body: Text('test-page:${state.pathParameters['code']}'),
            ),
          ),
        ],
      ),
    );
  }

  final loadedMessages = [
    ChatMessage(
      message: 'Halo, apa kabar?',
      senderType: 'psikolog',
      createdAt: DateTime(2026, 1, 5, 10),
    ),
  ];

  setUp(() {
    chatCubit = _MockChatCubit();
    authCubit = _MockAuthCubit();
    when(() => authCubit.state).thenReturn(const AuthState.authenticated(user));
  });

  testWidgets('shows a spinner while loading', (tester) async {
    when(() => chatCubit.state).thenReturn(const ChatState.loading());

    await tester.pumpWidget(harness(chatCubit, authCubit));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the error message when the initial load fails', (
    tester,
  ) async {
    when(() => chatCubit.state).thenReturn(
      const ChatState.loadFailed(
        ServerFailure('Gagal memuat percakapan', statusCode: 500),
      ),
    );

    await tester.pumpWidget(harness(chatCubit, authCubit));

    expect(find.text('Gagal memuat percakapan'), findsOneWidget);
  });

  testWidgets('shows loaded messages from both senders', (tester) async {
    when(
      () => chatCubit.state,
    ).thenReturn(ChatState.loaded(messages: loadedMessages, ended: false));

    await tester.pumpWidget(harness(chatCubit, authCubit));

    expect(find.text('Halo, apa kabar?'), findsOneWidget);
  });

  testWidgets(
    'shows an honest "Terkirim" label, never a fabricated delivered/read '
    'receipt — the old app\'s MessageStatus was decorative, this one is not',
    (tester) async {
      final withStatuses = [
        ChatMessage(
          message: 'Pending',
          senderType: 'participant',
          createdAt: DateTime(2026, 1, 5, 10),
          status: ChatMessageStatus.pending,
        ),
        ChatMessage(
          message: 'Sent',
          senderType: 'participant',
          createdAt: DateTime(2026, 1, 5, 10, 1),
        ),
        ChatMessage(
          message: 'Failed',
          senderType: 'participant',
          createdAt: DateTime(2026, 1, 5, 10, 2),
          status: ChatMessageStatus.failed,
        ),
      ];
      when(
        () => chatCubit.state,
      ).thenReturn(ChatState.loaded(messages: withStatuses, ended: false));

      await tester.pumpWidget(harness(chatCubit, authCubit));

      expect(find.text('Mengirim...'), findsOneWidget);
      expect(find.text('Terkirim'), findsOneWidget);
      expect(find.text('Gagal terkirim'), findsOneWidget);
      expect(find.text('Delivered'), findsNothing);
      expect(find.text('Read'), findsNothing);
      expect(find.text('Dibaca'), findsNothing);
    },
  );

  testWidgets('sending a message calls sendMessage with the real user id', (
    tester,
  ) async {
    when(
      () => chatCubit.state,
    ).thenReturn(ChatState.loaded(messages: loadedMessages, ended: false));
    when(
      () => chatCubit.sendMessage(
        message: any(named: 'message'),
        senderId: any(named: 'senderId'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(harness(chatCubit, authCubit));

    await tester.enterText(find.byType(TextField), 'Terima kasih');
    await tester.tap(find.byIcon(Icons.send_rounded));

    verify(
      () => chatCubit.sendMessage(message: 'Terima kasih', senderId: 'user-1'),
    ).called(1);
  });

  testWidgets(
    '"Mulai Tes Kedua" navigates to the real test page now that test is '
    'migrated — found stale during the 2026-07-14 GAPS.md compilation '
    '(this used to be a placeholder dialog saying "test isn\'t migrated '
    'yet", which had stopped being true and was never revisited)',
    (tester) async {
      when(
        () => chatCubit.state,
      ).thenReturn(ChatState.loaded(messages: loadedMessages, ended: true));

      await tester.pumpWidget(harness(chatCubit, authCubit));

      expect(find.text('Konseling Selesai'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text('Mulai Tes Kedua'));
      await tester.pumpAndSettle();

      expect(find.text('test-page:ABC123'), findsOneWidget);
    },
  );
}
