import 'package:freezed_annotation/freezed_annotation.dart';

part 'counseling_session.freezed.dart';

/// One entry in the counseling session list (`GET /chat/list`). Named
/// `code`, not `voucher` — same naming decision as `feature_history`'s
/// `TestHistoryItem.code`, both backed by the same `kode_voucher` field —
/// kept consistent across features rather than reinventing a name for the
/// same real-world value.
///
/// `status` stays a plain `String`: the old app's `CounselingTimeline`
/// only ever compares it against the literal `'finished'`
/// (`docs/MIGRATION_PLAYBOOK.md` §0 — no confirmed-exhaustive value list,
/// so no closed enum invented from an unverified assumption).
@freezed
abstract class CounselingSession with _$CounselingSession {
  const factory CounselingSession({
    required int id,
    required String code,
    required String psychologist,
    required String status,
    required DateTime createdAt,
  }) = _CounselingSession;
}
