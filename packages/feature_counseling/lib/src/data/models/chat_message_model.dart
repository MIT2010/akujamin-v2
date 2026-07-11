import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/chat_message.dart';

part 'chat_message_model.freezed.dart';
part 'chat_message_model.g.dart';

DateTime _parseCreatedAt(dynamic value) =>
    DateTime.tryParse(value as String? ?? '') ?? DateTime.now();

/// DTO shared by two sources with the same shape: `/chat/detail-conversation`'s
/// `data` array (history) and the `sent` websocket event's payload (live
/// messages) — confirmed identical field names by reading the old app's
/// `ChatModel.fromJson`, used by both `CounselingRepositoryImpl.getChat`
/// and `ChatStateCubit`'s socket listener
/// (`ChatModel.fromJson(event.payload)`).
///
/// `created_at` uses a lenient `tryParse ?? DateTime.now()` fallback —
/// matching the old app exactly, not tightened to a strict parse like
/// [CounselingSessionModel]'s `tanggal`. Deliberately different from that
/// stricter field: the old app itself treats them differently (this one
/// tolerates a missing/malformed timestamp, `tanggal` does not), and
/// nothing here overrides that judgment call.
@freezed
abstract class ChatMessageModel with _$ChatMessageModel {
  const ChatMessageModel._();

  const factory ChatMessageModel({
    required String message,
    @JsonKey(name: 'sender_type') required String senderType,
    @JsonKey(name: 'created_at', fromJson: _parseCreatedAt)
    required DateTime createdAt,
  }) = _ChatMessageModel;

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageModelFromJson(json);

  ChatMessage toEntity() => ChatMessage(
    message: message,
    senderType: senderType,
    createdAt: createdAt,
  );
}
