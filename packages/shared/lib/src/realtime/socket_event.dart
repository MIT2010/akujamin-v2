/// A single event received over the shared websocket connection — `type`
/// is the Pusher event name (`'sent'`/`'ended'` for counseling,
/// `'konfirmasi.user'`/`'konfirmasi.payment'` for payment,
/// `'konfirmasi.kelulusan'` for the dashboard shell's exam-confirmation
/// listener), `payload` its decoded `message` field. Not a domain entity
/// with `Result`/`Failure` plumbing: this is an internal pub/sub
/// notification, not an HTTP call with an error boundary to cross.
class SocketEvent {
  final String type;
  final Map<String, dynamic> payload;

  const SocketEvent({required this.type, required this.payload});
}
