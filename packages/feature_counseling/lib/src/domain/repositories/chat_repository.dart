import 'package:core/core.dart';

import '../entities/chat_message.dart';

/// Abstract contract (§18) for a single chat thread's history + sending —
/// kept separate from [CounselingRepository] (the session list) the same
/// way `feature_history` split `HistoryRepository`/`CertificateRepository`:
/// "fetch a thread's history and send to it" is its own bounded action,
/// not a variant of "list sessions." No UseCase (§21/ADR-004) — both
/// methods are thin pass-throughs, same conclusion as every other
/// migrated feature so far.
abstract class ChatRepository {
  Future<Result<Failure, List<ChatMessage>>> getMessages(String code);

  /// `senderId` is the current user's id — the old app also sends fixed
  /// `sender_type: 'participant'`/`type: 'konseling'` constants alongside
  /// it, kept as implementation details inside the datasource rather than
  /// exposed here, since they're never a real choice this call site makes.
  Future<Result<Failure, void>> sendMessage({
    required String code,
    required String message,
    required String senderId,
  });
}
