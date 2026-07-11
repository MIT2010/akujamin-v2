import 'socket_event.dart';

/// Abstract contract so [ChatCubit] (and its tests) never depend on
/// `dart_pusher_channels` directly — same "depend on an abstraction"
/// pattern as every repository in this codebase, applied to a realtime
/// gateway instead of an HTTP one.
abstract class CounselingSocketGateway {
  Stream<SocketEvent> get events;

  /// Connects (if not already) and subscribes to [channelName] — mirrors
  /// the old app's own `WebsocketDatasourceImpl.subscribe()`, which calls
  /// `connect()` itself before subscribing. Idempotent per channel name.
  Future<void> subscribe(String channelName);

  Future<void> unsubscribe(String channelName);

  /// Unsubscribes every channel and closes the connection entirely.
  Future<void> disconnect();
}
