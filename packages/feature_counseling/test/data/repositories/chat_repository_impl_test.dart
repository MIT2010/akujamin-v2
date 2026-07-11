import 'package:core/core.dart';
import 'package:feature_counseling/feature_counseling.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockChatRemoteDataSource extends Mock implements ChatRemoteDataSource {}

void main() {
  late _MockChatRemoteDataSource remote;
  late ChatRepositoryImpl repository;

  setUp(() {
    remote = _MockChatRemoteDataSource();
    repository = ChatRepositoryImpl(remote);
  });

  group('ChatRepositoryImpl.getMessages', () {
    test('returns Ok with the mapped entities when status is ok', () async {
      when(() => remote.getMessages('ABC123')).thenAnswer(
        (_) async => Ok(<String, dynamic>{
          'status': 'ok',
          'message': 'success',
          'data': [
            {
              'message': 'Halo',
              'sender_type': 'psikolog',
              'created_at': '2026-01-05T10:00:00.000Z',
            },
          ],
        }),
      );

      final result = await repository.getMessages('ABC123');

      expect(result.isOk, isTrue);
      final messages = (result as Ok<Failure, List<ChatMessage>>).value;
      expect(messages, hasLength(1));
      expect(messages.first.message, 'Halo');
      expect(messages.first.senderType, 'psikolog');
      expect(messages.first.status, ChatMessageStatus.sent);
    });

    test('returns Err when the envelope status is not ok', () async {
      when(() => remote.getMessages(any())).thenAnswer(
        (_) async => Ok(<String, dynamic>{
          'status': 'error',
          'message': 'Percakapan tidak ditemukan',
        }),
      );

      final result = await repository.getMessages('ABC123');

      expect(result.isErr, isTrue);
      final failure = (result as Err<Failure, List<ChatMessage>>).failure;
      expect(failure, isA<ServerFailure>());
      expect(failure.message, 'Percakapan tidak ditemukan');
    });
  });

  group('ChatRepositoryImpl.sendMessage', () {
    test('passes through to the datasource unchanged', () async {
      when(
        () => remote.sendMessage(
          code: 'ABC123',
          message: 'Halo',
          senderId: 'user-1',
        ),
      ).thenAnswer((_) async => const Ok(null));

      final result = await repository.sendMessage(
        code: 'ABC123',
        message: 'Halo',
        senderId: 'user-1',
      );

      expect(result.isOk, isTrue);
      verify(
        () => remote.sendMessage(
          code: 'ABC123',
          message: 'Halo',
          senderId: 'user-1',
        ),
      ).called(1);
    });

    test('passes the datasource failure through unchanged', () async {
      when(
        () => remote.sendMessage(
          code: any(named: 'code'),
          message: any(named: 'message'),
          senderId: any(named: 'senderId'),
        ),
      ).thenAnswer((_) async => const Err(NetworkFailure()));

      final result = await repository.sendMessage(
        code: 'ABC123',
        message: 'Halo',
        senderId: 'user-1',
      );

      expect(result.isErr, isTrue);
      expect((result as Err<Failure, void>).failure, isA<NetworkFailure>());
    });
  });
}
