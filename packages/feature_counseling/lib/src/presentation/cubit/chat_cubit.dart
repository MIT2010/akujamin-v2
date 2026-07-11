import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../data/models/chat_message_model.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../realtime/counseling_socket_gateway.dart';
import '../../realtime/socket_event.dart';
import 'chat_state.dart';

/// No UseCase (§21/ADR-004) — `getMessages`/`sendMessage` are thin
/// pass-throughs to [ChatRepository]; the realtime wiring below is
/// orchestration this cubit genuinely owns, not something a UseCase would
/// meaningfully extract.
@injectable
class ChatCubit extends Cubit<ChatState> {
  ChatCubit(this._chatRepository, this._socketGateway)
    : super(const ChatState.initial());

  final ChatRepository _chatRepository;
  final CounselingSocketGateway _socketGateway;

  StreamSubscription<SocketEvent>? _eventSubscription;
  String? _code;
  bool _sessionEnded = false;

  String _channelName(String code) => 'konseling.$code';

  Future<void> getMessages(String code) async {
    if (state is ChatLoading) return;

    _code = code;
    emit(const ChatState.loading());

    final result = await _chatRepository.getMessages(code);

    result.fold((failure) => emit(ChatState.loadFailed(failure)), (messages) {
      emit(ChatState.loaded(messages: messages, ended: false));
      _listenForRealtimeUpdates(code);
    });
  }

  void _listenForRealtimeUpdates(String code) {
    _eventSubscription?.cancel();
    _eventSubscription = _socketGateway.events.listen((event) {
      switch (event.type) {
        case 'sent':
          _handleSent(code, event);
        case 'ended':
          _handleEnded(code, event);
      }
    });
    _socketGateway.subscribe(_channelName(code));
  }

  /// Real correction, not inherited from the old app (approved during the
  /// pre-code audit, MIGRATION_LOG.md's `counseling` row): the old app's
  /// equivalent listener only checked `sender_type != 'participant'`,
  /// never that the event's `kode_voucher` actually matches the chat
  /// that's open — a latent cross-channel bug (harmless while only one
  /// chat is ever open, but this gateway is a shared singleton, see
  /// `CounselingSocketGatewayImpl.unsubscribe`'s doc comment, so the risk
  /// is real here in a way it wasn't there). New code doesn't inherit it.
  void _handleSent(String code, SocketEvent event) {
    if (event.payload['sender_type'] == 'participant') return;
    if (event.payload['kode_voucher'] != code) return;

    final current = state;
    if (current is! ChatLoaded) return;

    // Parsing a pushed socket payload into the same entity shape the REST
    // response uses — the data layer's usual job, needed here because this
    // arrives push-based rather than through a repository call. Same
    // approach the old app's `ChatModel.fromJson(event.payload)` took.
    final incoming = ChatMessageModel.fromJson(event.payload).toEntity();
    emit(current.copyWith(messages: [...current.messages, incoming]));
  }

  void _handleEnded(String code, SocketEvent event) {
    if (event.payload['kode_voucher'] != code) return;

    final current = state;
    if (current is! ChatLoaded) return;

    _sessionEnded = true;
    emit(current.copyWith(ended: true));
    _socketGateway.unsubscribe(_channelName(code));
  }

  /// Optimistic local echo + the `sender_type == 'participant'` filter in
  /// [_handleSent] are one paired unit — landing only one half causes
  /// either a duplicate (both the optimistic echo and the server's own
  /// broadcast of it render) or a dropped message (neither does).
  Future<void> sendMessage({
    required String message,
    required String senderId,
  }) async {
    final current = state;
    if (current is! ChatLoaded || message.trim().isEmpty) return;

    final code = _code!;
    final optimistic = ChatMessage(
      message: message,
      senderType: 'participant',
      createdAt: DateTime.now(),
      status: ChatMessageStatus.pending,
    );

    emit(current.copyWith(messages: [...current.messages, optimistic]));

    final result = await _chatRepository.sendMessage(
      code: code,
      message: message,
      senderId: senderId,
    );

    final latest = state;
    if (latest is! ChatLoaded) return;

    final index = latest.messages.indexOf(optimistic);
    if (index == -1) return;

    final updated = [...latest.messages];
    updated[index] = optimistic.copyWith(
      status: result.isOk ? ChatMessageStatus.sent : ChatMessageStatus.failed,
    );
    emit(latest.copyWith(messages: updated));
  }

  @override
  Future<void> close() async {
    await _eventSubscription?.cancel();
    if (_code != null && !_sessionEnded) {
      await _socketGateway.unsubscribe(_channelName(_code!));
    }
    return super.close();
  }
}
