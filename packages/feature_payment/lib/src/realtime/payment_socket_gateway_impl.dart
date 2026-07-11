import 'dart:async';

import 'package:core/core.dart';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:injectable/injectable.dart';

import 'payment_socket_gateway.dart';
import 'reconnect_backoff.dart';
import 'socket_event.dart';

/// Self-contained websocket connection layer, scoped to `feature_payment`
/// — deliberately its own copy, not a shared dependency on
/// `feature_counseling`'s equivalent (see [ReconnectBackoff]'s doc
/// comment). Same shape as `CounselingSocketGatewayImpl`: connect-on-
/// subscribe, auto-resubscribe on reconnect, bounded exponential backoff
/// instead of the old app's immediate-unconditional-forever retry.
@LazySingleton(as: PaymentSocketGateway)
class PaymentSocketGatewayImpl implements PaymentSocketGateway {
  PaymentSocketGatewayImpl(this._env);

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
    await _connect();

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
