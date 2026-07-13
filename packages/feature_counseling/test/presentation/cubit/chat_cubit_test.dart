import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:feature_counseling/feature_counseling.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared/shared.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

/// A controllable fake, not a mock — the regression tests below need to
/// push real events onto a real stream and assert on real subscribe/
/// unsubscribe call history, which a mocktail mock's argument matchers
/// make awkward for a broadcast stream used across many test cases.
class _FakeSocketGateway implements SocketGateway {
  final _controller = StreamController<SocketEvent>.broadcast();
  final List<String> subscribedChannels = [];
  final List<String> unsubscribedChannels = [];

  @override
  Stream<SocketEvent> get events => _controller.stream;

  @override
  Future<void> subscribe(String channelName) async {
    subscribedChannels.add(channelName);
  }

  @override
  Future<void> unsubscribe(String channelName) async {
    unsubscribedChannels.add(channelName);
  }

  @override
  Future<void> disconnect() async {}

  void emit(SocketEvent event) => _controller.add(event);

  Future<void> dispose() => _controller.close();
}

void main() {
  late _MockChatRepository repository;
  late _FakeSocketGateway gateway;

  final messages = [
    ChatMessage(
      message: 'Halo',
      senderType: 'psikolog',
      createdAt: DateTime(2026, 1, 5, 10),
    ),
  ];

  setUp(() {
    repository = _MockChatRepository();
    gateway = _FakeSocketGateway();
  });

  tearDown(() => gateway.dispose());

  group('ChatCubit.getMessages', () {
    blocTest<ChatCubit, ChatState>(
      'given the repository resolves the thread history',
      setUp: () {
        when(
          () => repository.getMessages('ABC123'),
        ).thenAnswer((_) async => Ok(messages));
      },
      build: () => ChatCubit(repository, gateway),
      act: (cubit) => cubit.getMessages('ABC123'),
      expect: () => [
        const ChatState.loading(),
        ChatState.loaded(messages: messages, ended: false),
      ],
      verify: (_) {
        expect(gateway.subscribedChannels, ['konseling.ABC123']);
      },
    );

    blocTest<ChatCubit, ChatState>(
      'given the repository fails',
      setUp: () {
        when(() => repository.getMessages(any())).thenAnswer(
          (_) async =>
              const Err(ServerFailure('Internal error', statusCode: 500)),
        );
      },
      build: () => ChatCubit(repository, gateway),
      act: (cubit) => cubit.getMessages('ABC123'),
      expect: () => [
        const ChatState.loading(),
        const ChatState.loadFailed(
          ServerFailure('Internal error', statusCode: 500),
        ),
      ],
    );
  });

  group('ChatCubit realtime — incoming messages', () {
    test('appends an incoming message from the psychologist', () async {
      when(
        () => repository.getMessages('ABC123'),
      ).thenAnswer((_) async => Ok(messages));
      final cubit = ChatCubit(repository, gateway);
      await cubit.getMessages('ABC123');

      gateway.emit(
        SocketEvent(
          type: 'sent',
          payload: {
            'message': 'Bagaimana kabarmu?',
            'sender_type': 'psikolog',
            'kode_voucher': 'ABC123',
            'created_at': '2026-01-05T10:05:00.000Z',
          },
        ),
      );
      await pumpEventQueue();

      final state = cubit.state as ChatLoaded;
      expect(state.messages, hasLength(2));
      expect(state.messages.last.message, 'Bagaimana kabarmu?');

      await cubit.close();
    });

    test(
      'ignores a sent event for a different kode_voucher — the fix this '
      'slice adds over the old app, which only checked sender_type',
      () async {
        when(
          () => repository.getMessages('ABC123'),
        ).thenAnswer((_) async => Ok(messages));
        final cubit = ChatCubit(repository, gateway);
        await cubit.getMessages('ABC123');

        gateway.emit(
          SocketEvent(
            type: 'sent',
            payload: {
              'message': 'Pesan sesi lain',
              'sender_type': 'psikolog',
              'kode_voucher': 'XYZ999',
              'created_at': '2026-01-05T10:05:00.000Z',
            },
          ),
        );
        await pumpEventQueue();

        final state = cubit.state as ChatLoaded;
        expect(state.messages, hasLength(1)); // unchanged

        await cubit.close();
      },
    );

    test(
      'marks the thread ended and unsubscribes when the session ends',
      (() async {
        when(
          () => repository.getMessages('ABC123'),
        ).thenAnswer((_) async => Ok(messages));
        final cubit = ChatCubit(repository, gateway);
        await cubit.getMessages('ABC123');

        gateway.emit(
          SocketEvent(type: 'ended', payload: {'kode_voucher': 'ABC123'}),
        );
        await pumpEventQueue();

        final state = cubit.state as ChatLoaded;
        expect(state.ended, isTrue);
        expect(gateway.unsubscribedChannels, ['konseling.ABC123']);

        // close() after an ended session must not unsubscribe a second
        // time — the channel is already gone.
        await cubit.close();
        expect(gateway.unsubscribedChannels, ['konseling.ABC123']);
      }),
    );
  });

  group(
    'ChatCubit.sendMessage — optimistic echo, the paired-unit regression',
    () {
      test('the optimistic local echo does not duplicate when the server '
          'broadcasts the same message back over the socket', () async {
        when(
          () => repository.getMessages('ABC123'),
        ).thenAnswer((_) async => Ok(messages));
        when(
          () => repository.sendMessage(
            code: 'ABC123',
            message: 'Terima kasih',
            senderId: 'user-1',
          ),
        ).thenAnswer((_) async => const Ok(null));

        final cubit = ChatCubit(repository, gateway);
        await cubit.getMessages('ABC123');

        await cubit.sendMessage(message: 'Terima kasih', senderId: 'user-1');

        var state = cubit.state as ChatLoaded;
        expect(state.messages, hasLength(2)); // history + optimistic echo
        expect(state.messages.last.status, ChatMessageStatus.sent);

        // The server broadcasts the participant's own message back over
        // the same channel — the old app's bug was appending this too,
        // producing a visible duplicate. The sender_type == 'participant'
        // filter must drop it.
        gateway.emit(
          SocketEvent(
            type: 'sent',
            payload: {
              'message': 'Terima kasih',
              'sender_type': 'participant',
              'kode_voucher': 'ABC123',
              'created_at': DateTime.now().toIso8601String(),
            },
          ),
        );
        await pumpEventQueue();

        state = cubit.state as ChatLoaded;
        expect(state.messages, hasLength(2)); // still 2 — no duplicate

        await cubit.close();
      });

      test('marks the optimistic echo failed when the send fails', () async {
        when(
          () => repository.getMessages('ABC123'),
        ).thenAnswer((_) async => Ok(messages));
        when(
          () => repository.sendMessage(
            code: 'ABC123',
            message: 'Terima kasih',
            senderId: 'user-1',
          ),
        ).thenAnswer((_) async => const Err(NetworkFailure()));

        final cubit = ChatCubit(repository, gateway);
        await cubit.getMessages('ABC123');
        await cubit.sendMessage(message: 'Terima kasih', senderId: 'user-1');

        final state = cubit.state as ChatLoaded;
        expect(state.messages.last.status, ChatMessageStatus.failed);

        await cubit.close();
      });
    },
  );

  group('ChatCubit.close', () {
    test('unsubscribes the channel when the session has not ended', () async {
      when(
        () => repository.getMessages('ABC123'),
      ).thenAnswer((_) async => Ok(messages));
      final cubit = ChatCubit(repository, gateway);
      await cubit.getMessages('ABC123');

      await cubit.close();

      expect(gateway.unsubscribedChannels, ['konseling.ABC123']);
    });
  });
}
