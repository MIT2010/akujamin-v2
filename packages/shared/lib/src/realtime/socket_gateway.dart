import 'socket_event.dart';

/// Abstract contract so any Cubit (and its tests) never depends on
/// `dart_pusher_channels` directly — same "depend on an abstraction"
/// pattern as every repository in this codebase, applied to a realtime
/// gateway instead of an HTTP one.
///
/// **One shared connection for the whole app, not one per feature** —
/// extracted here (from `feature_counseling`, then duplicated into
/// `feature_payment`) once `dashboard` shell became the third consumer,
/// and specifically because the shell's global, passive event listening
/// (MIGRATION_LOG.md permanent finding #1/#6) only works correctly
/// against a single shared connection: the old app's own
/// `WebsocketDatasourceImpl` is a single `sl<WebsocketDatasource>()`
/// singleton every feature subscribes channels on, and the dashboard
/// shell's `_listen()` never subscribes anything itself — it only
/// filters whatever's already flowing through that one shared stream,
/// regardless of which feature subscribed the channel. Two separate
/// per-feature connections (the shape `counseling`/`payment` shipped
/// with independently) cannot reproduce that: `dashboard` would have no
/// channel of its own to listen on.
abstract class SocketGateway {
  Stream<SocketEvent> get events;

  /// Connects (if not already) and subscribes to [channelName] — mirrors
  /// the old app's own `WebsocketDatasourceImpl.subscribe()`, which calls
  /// `connect()` itself before subscribing. Idempotent per channel name.
  Future<void> subscribe(String channelName);

  Future<void> unsubscribe(String channelName);

  /// Unsubscribes every channel and closes the connection entirely.
  Future<void> disconnect();
}
