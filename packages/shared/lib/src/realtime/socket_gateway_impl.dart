import 'dart:async';

import 'package:core/core.dart';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:injectable/injectable.dart';

import 'reconnect_backoff.dart';
import 'socket_event.dart';
import 'socket_gateway.dart';

/// One shared websocket connection for the whole app (§7 — see
/// [SocketGateway]'s doc comment for why this must be a single instance,
/// not one per feature). Mirrors the old app's `WebsocketDatasourceImpl`/
/// `ChannelManager` shape (connect-on-subscribe, auto-resubscribe on
/// reconnect via `subscribeIfNotUnsubscribed()`) with one deliberate
/// correction: the old app's `connectionErrorHandler` called `refresh()`
/// immediately and unconditionally on every error, forever. This uses
/// [ReconnectBackoff] instead — see that class's doc comment.
@LazySingleton(as: SocketGateway)
class SocketGatewayImpl implements SocketGateway {
  SocketGatewayImpl(this._env);

  final Env _env;

  StreamController<SocketEvent>? _controller;
  PusherChannelsClient? _client;
  final Map<String, Channel> _channels = {};
  final Map<String, StreamSubscription> _channelSubscriptions = {};
  final _backoff = ReconnectBackoff();
  bool _isConnected = false;
  bool _isConnecting = false;

  @override
  Stream<SocketEvent> get events {
    _controller ??= StreamController<SocketEvent>.broadcast();
    return _controller!.stream;
  }

  Future<void> _connect() async {
    if (_isConnected || _isConnecting) return;
    _isConnecting = true;

    _controller ??= StreamController<SocketEvent>.broadcast();

    final options = PusherChannelsOptions.fromHost(
      scheme: _env.wsScheme,
      host: _env.wsHost,
      key: _env.wsKey,
      port: int.tryParse(_env.wsPort),
      shouldSupplyMetadataQueries: true,
      metadata: const PusherChannelsOptionsMetadata.byDefault(),
    );

    _client ??= PusherChannelsClient.websocket(
      options: options,
      connectionErrorHandler: (exception, trace, refresh) {
        Future.delayed(_backoff.next(), refresh);
      },
    );

    _client!.onConnectionEstablished.listen((_) {
      _isConnected = true;
      _isConnecting = false;
      _backoff.reset();
      _resubscribeAll();
    });

    await _client!.connect();
  }

  void _resubscribeAll() {
    for (final channel in _channels.values) {
      channel.subscribeIfNotUnsubscribed();
    }
  }

  @override
  Future<void> subscribe(String channelName) async {
    await _connect(); // ensure connection, same as the old app

    if (_channels.containsKey(channelName)) return;

    final channel = _client!.publicChannel(channelName);
    _channels[channelName] = channel;
    _channelSubscriptions[channelName] = channel.bindToAll().listen((event) {
      final payload = event.tryGetDataAsMap()?['message'];
      _controller?.add(
        SocketEvent(
          type: event.name,
          payload: payload is Map
              ? payload.cast<String, dynamic>()
              : <String, dynamic>{},
        ),
      );
    });
    channel.subscribe();
  }

  /// Unsubscribing the *last* channel tears the connection down entirely
  /// — this gateway is a single `@LazySingleton` shared by every feature
  /// that ever exists (`ChatCubit`, `PaymentCubit`, the dashboard shell),
  /// so any one of them calling `unsubscribe()` must not assume it's safe
  /// to also force a full `disconnect()` itself (that would kill a
  /// connection a *different*, still-live consumer needs). Tying teardown
  /// to "no channels left" instead of "one specific consumer is done"
  /// makes this correct regardless of how many features are using the
  /// connection at once.
  @override
  Future<void> unsubscribe(String channelName) async {
    final channel = _channels.remove(channelName);
    if (channel == null) return;

    await _channelSubscriptions.remove(channelName)?.cancel();
    channel.unsubscribe();

    if (_channels.isEmpty) {
      await _teardownConnection();
    }
  }

  @override
  Future<void> disconnect() async {
    for (final name in _channels.keys.toList()) {
      await _channelSubscriptions.remove(name)?.cancel();
      _channels.remove(name)?.unsubscribe();
    }
    await _teardownConnection();
  }

  Future<void> _teardownConnection() async {
    if (!_isConnected && !_isConnecting) return;

    await _client?.disconnect();
    await _controller?.close();
    _client?.dispose();

    _isConnected = false;
    _isConnecting = false;
    _backoff.reset();
    _controller = null;
    _client = null;
  }
}
