/// A single event received over the websocket connection — `type` is the
/// Pusher event name (`'konfirmasi.user'`, `'konfirmasi.payment'`),
/// `payload` its decoded `message` field.
class SocketEvent {
  final String type;
  final Map<String, dynamic> payload;

  const SocketEvent({required this.type, required this.payload});
}
