import 'package:freezed_annotation/freezed_annotation.dart';

part 'test_history_item.freezed.dart';

/// One entry in a user's test history. Deliberately **not** named
/// `Voucher`/`VoucherEntity` (the old app's name for this) — AUDIT.md §6
/// found that name is actively misleading (it's not a discount code, it's
/// the test-session entity itself: real endpoints are `/tes/create`,
/// `/tes/batal-tes`, real fields are `psychologist`/`testAttempt`/
/// `testResult`/`certificateUrl`). Migrating the *name* forward would carry
/// the confusion into new code that never had a reason to inherit it.
///
/// `status` stays a plain `String`, not an enum: the old app itself only
/// ever compares it against literal strings
/// (`'Belum Tes'`/`'Sedang Tes'`/`'Konseling'`/`'Lulus'`/`'Tidak Lulus'`/
/// `'Selesai'`, see `HistoryView`'s doc comment) — no confirmed-exhaustive
/// list of every value the real API can return, so this doesn't invent a
/// closed enum from an unverified assumption (docs/MIGRATION_PLAYBOOK.md §0).
@freezed
abstract class TestHistoryItem with _$TestHistoryItem {
  const factory TestHistoryItem({
    required String code,
    required String job,
    required String destinationCountry,
    required String status,
    required String institution,
    required String psychologist,
    required String testAttempt,
    required String testResult,
    required DateTime createdAt,
    String? certificateUrl,
  }) = _TestHistoryItem;
}
