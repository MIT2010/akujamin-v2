import 'dart:async';

import 'package:authentication/authentication.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:feature_payment/feature_payment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/src/dashboard_notification_listener.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared/shared.dart';

/// A controllable fake, not a mock — same reasoning as
/// `feature_counseling`'s `_FakeSocketGateway`: these tests push real
/// events onto a real stream.
class _FakeSocketGateway implements SocketGateway {
  final _controller = StreamController<SocketEvent>.broadcast();
  final List<String> unsubscribedChannels = [];

  @override
  Stream<SocketEvent> get events => _controller.stream;

  @override
  Future<void> subscribe(String channelName) async {}

  @override
  Future<void> unsubscribe(String channelName) async {
    unsubscribedChannels.add(channelName);
  }

  @override
  Future<void> disconnect() async {}

  void emit(SocketEvent event) => _controller.add(event);

  Future<void> dispose() => _controller.close();
}

class _MockNotificationGateway extends Mock implements NotificationGateway {}

class _MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

class _MockPaymentRepository extends Mock implements PaymentRepository {}

class _MockAppRouter extends Mock implements AppRouter {}

void main() {
  late _FakeSocketGateway socketGateway;
  late _MockNotificationGateway notificationGateway;
  late _MockAuthCubit authCubit;
  late _MockPaymentRepository paymentRepository;
  late _MockAppRouter appRouter;

  const user = User(id: 'user-1', email: 'a@example.com', role: 'peserta');

  // Built with the desired location already as its initialLocation, and
  // actually mounted via MaterialApp.router below (not a bare MaterialApp)
  // — a GoRouter never attached to a live Router widget never finishes
  // populating routerDelegate.currentConfiguration, which _isCurrentChat
  // reads.
  GoRouter buildRouter({String initialLocation = '/home'}) => GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/home', builder: (_, _) => const SizedBox()),
      GoRoute(path: '/chat/:code', builder: (_, _) => const SizedBox()),
    ],
  );

  late GoRouter router;

  setUp(() {
    socketGateway = _FakeSocketGateway();
    notificationGateway = _MockNotificationGateway();
    authCubit = _MockAuthCubit();
    paymentRepository = _MockPaymentRepository();
    appRouter = _MockAppRouter();
    router = buildRouter();

    when(() => appRouter.router).thenAnswer((_) => router);
    when(() => authCubit.state).thenReturn(AuthState.authenticated(user));
    when(
      () => notificationGateway.show(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => paymentRepository.getPsychologistId(),
    ).thenAnswer((_) async => null);

    getIt
      ..registerSingleton<SocketGateway>(socketGateway)
      ..registerSingleton<NotificationGateway>(notificationGateway)
      ..registerSingleton<AuthCubit>(authCubit)
      ..registerSingleton<PaymentRepository>(paymentRepository)
      ..registerSingleton<AppRouter>(appRouter);
  });

  tearDown(() async {
    await socketGateway.dispose();
    await getIt.reset();
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    DashboardNotificationListener(
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  group('DashboardNotificationListener — confirmationPassed', () {
    testWidgets(
      'shows a generic notification and never the raw payload, for the '
      "current user's psychologist",
      (tester) async {
        await pump(tester);

        socketGateway.emit(
          SocketEvent(
            type: 'konfirmasi.kelulusan',
            payload: {
              'from': 'psikolog.user-1',
              'payload': {'status_lulus': 'lulus', 'nama': 'Rahasia'},
            },
          ),
        );
        await tester.pumpAndSettle();

        verify(
          () => notificationGateway.show(
            id: 1,
            title: 'Konfirmasi Kelulusan',
            body: 'Ada pembaruan status kelulusan tes kamu.',
            payload: null,
          ),
        ).called(1);
      },
    );

    testWidgets('ignores an event addressed to a different psychologist', (
      tester,
    ) async {
      await pump(tester);

      socketGateway.emit(
        SocketEvent(
          type: 'konfirmasi.kelulusan',
          payload: {
            'from': 'psikolog.someone-else',
            'payload': {'status_lulus': 'lulus'},
          },
        ),
      );
      await tester.pumpAndSettle();

      verifyNever(
        () => notificationGateway.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          payload: any(named: 'payload'),
        ),
      );
    });

    testWidgets(
      'clears the stored psychologist id and unsubscribes when the status '
      'is final (not konseling) — ported as-is from the old app, already '
      'safe',
      (tester) async {
        when(
          () => paymentRepository.getPsychologistId(),
        ).thenAnswer((_) async => 'psych-1');
        when(
          () => paymentRepository.clearPsychologistId(),
        ).thenAnswer((_) async {});

        await pump(tester);

        socketGateway.emit(
          SocketEvent(
            type: 'konfirmasi.kelulusan',
            payload: {
              'from': 'psikolog.user-1',
              'payload': {'status_lulus': 'lulus'},
            },
          ),
        );
        await tester.pumpAndSettle();

        verify(() => paymentRepository.clearPsychologistId()).called(1);
        expect(socketGateway.unsubscribedChannels, ['conf.psych-1']);
      },
    );

    testWidgets(
      'keeps the channel alive when the status is konseling — more events '
      'are still expected on it',
      (tester) async {
        when(
          () => paymentRepository.getPsychologistId(),
        ).thenAnswer((_) async => 'psych-1');

        await pump(tester);

        socketGateway.emit(
          SocketEvent(
            type: 'konfirmasi.kelulusan',
            payload: {
              'from': 'psikolog.user-1',
              'payload': {'status_lulus': 'konseling'},
            },
          ),
        );
        await tester.pumpAndSettle();

        verifyNever(() => paymentRepository.clearPsychologistId());
        expect(socketGateway.unsubscribedChannels, isEmpty);
      },
    );
  });

  group('DashboardNotificationListener — chatSent', () {
    testWidgets(
      'shows a generic notification and never the raw message, when the '
      "chat isn't the one currently open",
      (tester) async {
        await pump(tester);

        socketGateway.emit(
          SocketEvent(
            type: 'sent',
            payload: {
              'kode_voucher': 'ABC123',
              'sender_type': 'psikolog',
              'message': 'Pesan rahasia dari psikolog',
            },
          ),
        );
        await tester.pumpAndSettle();

        verify(
          () => notificationGateway.show(
            id: 1,
            title: 'Konseling',
            body: 'Kamu menerima pesan baru dari psikolog.',
            payload: null,
          ),
        ).called(1);
      },
    );

    testWidgets('suppresses the notification when that chat is already open — '
        'ChatPage/ChatCubit already shows it live', (tester) async {
      router = buildRouter(initialLocation: '/chat/ABC123');
      await pump(tester);

      socketGateway.emit(
        SocketEvent(
          type: 'sent',
          payload: {
            'kode_voucher': 'ABC123',
            'sender_type': 'psikolog',
            'message': 'Halo',
          },
        ),
      );
      await tester.pumpAndSettle();

      verifyNever(
        () => notificationGateway.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          payload: any(named: 'payload'),
        ),
      );
    });

    testWidgets(
      "ignores the participant's own echo of a message they just sent",
      (tester) async {
        await pump(tester);

        socketGateway.emit(
          SocketEvent(
            type: 'sent',
            payload: {
              'kode_voucher': 'ABC123',
              'sender_type': 'participant',
              'message': 'Halo',
            },
          ),
        );
        await tester.pumpAndSettle();

        verifyNever(
          () => notificationGateway.show(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            payload: any(named: 'payload'),
          ),
        );
      },
    );
  });

  group('DashboardNotificationListener — chatEnded', () {
    testWidgets('shows the same safe static text the old app already used — no '
        'content fix needed here, just the shared-gateway port', (
      tester,
    ) async {
      await pump(tester);

      socketGateway.emit(
        SocketEvent(type: 'ended', payload: {'kode_voucher': 'ABC123'}),
      );
      await tester.pumpAndSettle();

      verify(
        () => notificationGateway.show(
          id: 1,
          title: 'Konseling',
          body:
              'Sesi konseling telah berakhir. Kamu bisa melanjutkan ujian '
              'ke 2.',
          payload: null,
        ),
      ).called(1);
    });

    testWidgets('suppresses the notification when that chat is already open', (
      tester,
    ) async {
      router = buildRouter(initialLocation: '/chat/ABC123');
      await pump(tester);

      socketGateway.emit(
        SocketEvent(type: 'ended', payload: {'kode_voucher': 'ABC123'}),
      );
      await tester.pumpAndSettle();

      verifyNever(
        () => notificationGateway.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          payload: any(named: 'payload'),
        ),
      );
    });
  });
}
