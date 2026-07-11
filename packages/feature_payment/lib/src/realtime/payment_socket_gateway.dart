import 'socket_event.dart';

/// Abstract contract so [PaymentCubit] (and its tests) never depend on
/// `dart_pusher_channels` directly — same pattern as
/// `feature_counseling`'s `CounselingSocketGateway`.
abstract class PaymentSocketGateway {
  Stream<SocketEvent> get events;

  Future<void> subscribe(String channelName);

  Future<void> unsubscribe(String channelName);

  Future<void> disconnect();
}
