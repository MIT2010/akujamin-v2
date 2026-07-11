import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Both endpoints send `FormData`, matching the old app exactly — not
/// incidental: MIGRATION_LOG.md's permanent finding #3 verified (directly
/// against `dio`'s source, not inferred) that `FormData` bodies aren't
/// logged in full the way a raw JSON body would be, so keeping the same
/// transport shape here preserves that property, not just old-app
/// fidelity for its own sake.
@injectable
class ChatRemoteDataSource {
  final ApiClient _client;
  ChatRemoteDataSource(this._client);

  Future<Result<Failure, Map<String, dynamic>>> getMessages(String code) {
    return _client.post<Map<String, dynamic>>(
      '/chat/detail-conversation',
      data: FormData.fromMap({'kode_voucher': code}),
      parser: (json) => json as Map<String, dynamic>,
    );
  }

  /// `sender_type: 'participant'` and `type: 'konseling'` are constants,
  /// not real choices this call site makes — kept here rather than on
  /// [ChatRepository]'s public signature (see that class's doc comment).
  Future<Result<Failure, void>> sendMessage({
    required String code,
    required String message,
    required String senderId,
  }) {
    return _client.post<void>(
      '/chat/send',
      data: FormData.fromMap({
        'kode_voucher': code,
        'message': message,
        'sender_type': 'participant',
        'sender_id': senderId,
        'type': 'konseling',
      }),
      parser: (_) {},
    );
  }
}
