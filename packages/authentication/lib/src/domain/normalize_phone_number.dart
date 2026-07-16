/// Turns a locally-typed Indonesian phone number into the `62`-prefixed
/// form the backend expects, used by both [SendOtpUseCase] and
/// [VerifyOtpUseCase] before they call [AuthRepository].
///
/// **Real bug, found 2026-07-16 during live-backend UI testing**: both use
/// cases used to do `'62$phone'` unconditionally — correct only when the
/// user types their number *without* the leading `0` (`81211112222`).
/// Typing it the way virtually every Indonesian phone number is actually
/// written (`081211112222`, leading `0`) produced `62081211112222` — a
/// malformed 14-digit number, confirmed via a real `send-otp` request
/// (`"phone_number": "62081211112222"`) that the backend silently accepted
/// and created a permanent account under. In production, with real
/// SMS/WhatsApp delivery, the OTP would go to a number that doesn't exist —
/// this would break login for most real users, not just cosmetically mangle
/// a display string.
///
/// Handles the three ways a user might type it: `081211112222` (leading
/// `0`, by far the most common), `81211112222` (no leading `0`), and
/// `6281211112222` (already includes the country code, e.g. pasted from
/// somewhere) — the last case is left untouched rather than prefixed again
/// into `6262...`.
String normalizePhoneNumber(String rawPhoneNumber) {
  final trimmed = rawPhoneNumber.trim();
  if (trimmed.startsWith('62')) return trimmed;
  if (trimmed.startsWith('0')) return '62${trimmed.substring(1)}';
  return '62$trimmed';
}
