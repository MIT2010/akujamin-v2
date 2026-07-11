/// Exponential backoff with a cap for websocket reconnect attempts.
///
/// Same policy as `feature_counseling`'s `ReconnectBackoff` (see that
/// class's doc comment for the full reasoning) — deliberately not shared
/// between the two packages yet: this is the second real consumer of the
/// idea, not the second consumer of a shared *implementation*, per
/// MIGRATION_LOG.md's "generic by design from day one" vs. "starts
/// feature-specific, promoted only once reuse is proven" note. Extraction
/// into a shared `packages/websocket` should happen deliberately, once,
/// not be smuggled in as a side effect of building payment.
///
/// `1s → 2s → 4s → ... → 30s` is intentionally the *same* policy as
/// counseling's, not a payment-specific tuning: payment already has its
/// own manual fallbacks for a missed real-time event (the confirmation
/// step's 5-minute timeout, the review step's "Cek Status Pembayaran"
/// button), so there's no reason for its reconnect tolerance to differ.
class ReconnectBackoff {
  ReconnectBackoff({
    this.base = const Duration(seconds: 1),
    this.max = const Duration(seconds: 30),
  });

  final Duration base;
  final Duration max;

  int _attempt = 0;

  Duration next() {
    final multiplier = 1 << _attempt;
    final delay = base * multiplier;
    _attempt++;
    return delay > max ? max : delay;
  }

  void reset() => _attempt = 0;
}
