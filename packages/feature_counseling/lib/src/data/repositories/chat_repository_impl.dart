import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_datasource.dart';
import '../models/chat_message_model.dart';

/// §20 — same envelope shape as `CounselingRepositoryImpl`
/// (`{status, message, data}`, `data` not `datas`), confirmed by reading
/// the old app's `CounselingRepositoryImpl.getChat` in full.
@LazySingleton(as: ChatRepository)
class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource _remote;
  ChatRepositoryImpl(this._remote);

  @override
  Future<Result<Failure, List<ChatMessage>>> getMessages(String code) async {
    final result = await _remote.getMessages(code);

    return result.fold(Err.new, (envelope) {
      if (envelope['status'] != 'ok') {
        return Err(
          ServerFailure(
            envelope['message'] as String? ?? 'Gagal memuat percakapan',
          ),
        );
      }

      final data = envelope['data'] as List;
      return Ok(
        data
            .map(
              (e) => ChatMessageModel.fromJson(
                e as Map<String, dynamic>,
              ).toEntity(),
            )
            .toList(),
      );
    });
  }

  @override
  Future<Result<Failure, void>> sendMessage({
    required String code,
    required String message,
    required String senderId,
  }) {
    return _remote.sendMessage(
      code: code,
      message: message,
      senderId: senderId,
    );
  }
}
