import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_message.freezed.dart';

/// A single chat message. `senderType` stays a plain `String` (compared
/// against the literal `'participant'` at the UI layer, same value the old
/// app's `ChatEntity.sender` used) — no confirmed-exhaustive list of every
/// value the real API can send for the psychologist's side, so no closed
/// enum invented from an unverified assumption.
///
/// **`status` only ever reflects what's actually knowable client-side —
/// deliberately not a fake read-receipt system.** The old app's UI had a
/// `MessageStatus` enum with `sending/sent/delivered/read` values, but
/// audited: it was purely decorative, never driven by any real state
/// (`Message.status` always defaulted to `sent`, nothing in
/// `ChatStateCubit` ever set `delivered`/`read`). This entity's
/// [ChatMessageStatus] only has [ChatMessageStatus.pending] (optimistic
/// local echo, send request in flight) and [ChatMessageStatus.sent]
/// (either fetched from history, or the local echo's send request
/// succeeded) — there is no `delivered`/`read`, because the app genuinely
/// has no way to know either of those things.
@freezed
abstract class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String message,
    required String senderType,
    required DateTime createdAt,
    @Default(ChatMessageStatus.sent) ChatMessageStatus status,
  }) = _ChatMessage;
}

enum ChatMessageStatus { pending, sent, failed }
