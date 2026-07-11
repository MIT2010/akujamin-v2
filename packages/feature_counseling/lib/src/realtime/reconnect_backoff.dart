/// Exponential backoff with a cap for websocket reconnect attempts.
///
/// **Deliberate correction, not a faithful port** (approved during the
/// pre-code audit, docs/qa/counseling.md): the old app's
/// `connectionErrorHandler` called `refresh()` unconditionally and
/// immediately on every connection error, forever — no delay growth, no
/// cap, so a persistent server outage would retry as fast as each attempt
/// could fail. `1s → 2s → 4s → ... → 30s` (capped, not unbounded) keeps
/// reconnection feeling near-instant for a brief blip (the common case for
/// a chat feature, where users expect messages to keep flowing) while
/// protecting a genuinely down server from being hammered — 30s was
/// chosen as a cap most users will tolerate without assuming the feature
/// is broken, not derived from any server-side rate limit (none is
/// documented). Resets to the base delay after a successful reconnect —
/// standard backoff-with-reset, not just growing forever.
class ReconnectBackoff {
  ReconnectBackoff({
    this.base = const Duration(seconds: 1),
    this.max = const Duration(seconds: 30),
  });

  final Duration base;
  final Duration max;

  int _attempt = 0;

  /// The delay to wait before the next reconnect attempt, then advances
  /// the internal attempt counter.
  Duration next() {
    final multiplier = 1 << _attempt;
    final delay = base * multiplier;
    _attempt++;
    return delay > max ? max : delay;
  }

  /// Called after a successful (re)connection.
  void reset() => _attempt = 0;
}
