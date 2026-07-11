import 'package:core/core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/chat_message.dart';

part 'chat_state.freezed.dart';

/// freezed 3.x `sealed class` state union (ADR-005). Unlike `HistoryState`/
/// `CertificateState`'s plain `initial/loading/loaded/error` shape,
/// [ChatLoaded] carries an `ended` flag rather than being a separate
/// state variant — a send failure or an incoming message must not discard
/// the already-loaded message list the way switching to a bare `error`
/// state would (matches the old app's own `ChatState`, which kept `chats`
/// and `error` as sibling fields rather than mutually exclusive states).
@freezed
sealed class ChatState with _$ChatState {
  const factory ChatState.initial() = ChatInitial;
  const factory ChatState.loading() = ChatLoading;
  const factory ChatState.loadFailed(Failure failure) = ChatLoadFailed;
  const factory ChatState.loaded({
    required List<ChatMessage> messages,
    required bool ended,
  }) = ChatLoaded;
}
