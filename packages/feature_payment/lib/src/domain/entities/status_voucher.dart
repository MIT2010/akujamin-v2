/// The lifecycle stage of a voucher, resolved from `info_registrasi.
/// status_ujian` (`GET /tes/cek-voucher`) — **not** the same field as
/// `feature_history`'s flat `status_ujian` from `list-voucher` (a
/// different, display-only vocabulary; see MIGRATION_LOG.md's "Resolved —
/// payment status codes" section for the full three-vocabulary map).
///
/// The API's own literal codes (`'PT'`/`'TP'`) have no confirmed literal
/// expansion — no response example or documentation text was available
/// to translate them from, only their functional behavior in
/// `PaymentStateCubit._mapStatus()`. [underReview]/[paid] are a
/// deliberate refinement beyond the old app's single catch-all
/// `PaymentStatus.review` (approved 2026-07-11) — the old app split that
/// same distinction back out via a separate `isSuccess` flag instead of a
/// fourth enum value.
enum StatusVoucher {
  /// API: `'PT'`. Demography form + psychologist selection required.
  needsRegistrationData,

  /// API: `'TP'`. Bank transfer + proof-of-payment upload required.
  needsPayment,

  /// API: else, and `pembayaran.status != 'PAID'`. Awaiting confirmation.
  underReview,

  /// API: else, and `pembayaran.status == 'PAID'`. Voucher usable.
  paid,
}
