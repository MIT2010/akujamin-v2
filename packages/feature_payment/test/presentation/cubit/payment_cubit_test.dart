import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:feature_payment/feature_payment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared/shared.dart';

class _MockPaymentRepository extends Mock implements PaymentRepository {}

class _MockFormInputRepository extends Mock implements FormInputRepository {}

/// A controllable fake, not a mock — same reasoning as
/// `feature_counseling`'s `_FakeSocketGateway`: the disconnect-always
/// regression test below needs real subscribe/unsubscribe call history
/// across multiple cubit lifecycles.
class _FakeSocketGateway implements PaymentSocketGateway {
  final _controller = StreamController<SocketEvent>.broadcast();
  final List<String> subscribedChannels = [];
  final List<String> unsubscribedChannels = [];

  @override
  Stream<SocketEvent> get events => _controller.stream;

  @override
  Future<void> subscribe(String channelName) async {
    subscribedChannels.add(channelName);
  }

  @override
  Future<void> unsubscribe(String channelName) async {
    unsubscribedChannels.add(channelName);
  }

  @override
  Future<void> disconnect() async {}

  void emit(SocketEvent event) => _controller.add(event);

  Future<void> dispose() => _controller.close();
}

void main() {
  late _MockPaymentRepository repository;
  late _MockFormInputRepository formInputRepository;
  late _FakeSocketGateway gateway;

  setUp(() {
    repository = _MockPaymentRepository();
    formInputRepository = _MockFormInputRepository();
    gateway = _FakeSocketGateway();

    when(() => repository.savePsychologistId(any())).thenAnswer((_) async {});
    when(() => repository.getPsychologistId()).thenAnswer((_) async => null);
    when(() => repository.clearPsychologistId()).thenAnswer((_) async {});
  });

  tearDown(() => gateway.dispose());

  PaymentCubit build() =>
      PaymentCubit(repository, formInputRepository, gateway);

  group('PaymentCubit.initialize', () {
    blocTest<PaymentCubit, PaymentState>(
      "needsRegistrationData ('PT') moves to the demography step and loads "
      'the form schema',
      setUp: () {
        when(() => repository.checkVoucher()).thenAnswer(
          (_) async => Ok(
            const RegistrationStatus(
              status: StatusVoucher.needsRegistrationData,
              formData: {},
            ),
          ),
        );
        when(() => formInputRepository.getForm('/tes/pertanyaan')).thenAnswer(
          (_) async => const Ok([
            FormInputField(
              label: 'psikologi',
              display: 'Psikolog',
              type: 'select',
              validate: true,
              readOnly: false,
            ),
          ]),
        );
      },
      build: build,
      act: (cubit) => cubit.initialize('user-1'),
      verify: (cubit) {
        expect(cubit.state.step, PaymentStep.demography);
        expect(cubit.state.forms, hasLength(1));
      },
    );

    blocTest<PaymentCubit, PaymentState>(
      "needsPayment ('TP') connects the socket and loads the payment "
      'account for the previously-selected psychologist',
      setUp: () {
        when(() => repository.checkVoucher()).thenAnswer(
          (_) async => Ok(
            const RegistrationStatus(
              status: StatusVoucher.needsPayment,
              formData: {'psikologi': '27'},
            ),
          ),
        );
        when(() => repository.getPaymentAccount('27')).thenAnswer(
          (_) async => Ok(
            const PaymentAccountDetail(
              bankName: 'Bank Mandiri',
              bankAccount: '123',
              price: '150000',
            ),
          ),
        );
      },
      build: build,
      act: (cubit) => cubit.initialize('user-1'),
      verify: (cubit) {
        expect(cubit.state.step, PaymentStep.payment);
        expect(cubit.state.account?.bankName, 'Bank Mandiri');
        expect(gateway.subscribedChannels, ['conf.27']);
      },
    );

    blocTest<PaymentCubit, PaymentState>(
      'underReview/paid connects the socket and moves straight to review',
      setUp: () {
        when(() => repository.checkVoucher()).thenAnswer(
          (_) async => Ok(
            const RegistrationStatus(
              status: StatusVoucher.paid,
              formData: {'psikologi': '27'},
              isPaid: true,
            ),
          ),
        );
      },
      build: build,
      act: (cubit) => cubit.initialize('user-1'),
      verify: (cubit) {
        expect(cubit.state.step, PaymentStep.review);
        expect(cubit.state.isPaid, isTrue);
        expect(gateway.subscribedChannels, ['conf.27']);
      },
    );
  });

  group('PaymentCubit.setInput — clear-on-parent-change', () {
    blocTest<PaymentCubit, PaymentState>(
      'a stale dependent field value is removed from formResults itself '
      'the moment its parent changes',
      build: build,
      seed: () => const PaymentState(
        forms: [
          FormInputField(
            label: 'provinsi',
            display: 'Provinsi',
            type: 'select',
            validate: true,
            readOnly: false,
          ),
          FormInputField(
            label: 'kota',
            display: 'Kota',
            type: 'select',
            validate: true,
            readOnly: false,
            requirements: ['provinsi'],
          ),
        ],
        formResults: {'provinsi': '35', 'kota': '3578'},
      ),
      act: (cubit) => cubit.setInput('provinsi', '32'),
      verify: (cubit) {
        expect(cubit.state.formResults['provinsi'], '32');
        expect(cubit.state.formResults.containsKey('kota'), isFalse);
      },
    );
  });

  group('PaymentCubit.submitPayment — proof-image cleanup', () {
    blocTest<PaymentCubit, PaymentState>(
      'deletes the local proof-of-payment file after a successful upload — '
      'the mandatory fix, not ported from the old app, proven against a '
      'real temp file rather than asserted from a comment',
      setUp: () {
        when(() => repository.sendPayment(any())).thenAnswer(
          (_) async => const Ok(null),
        );
      },
      build: build,
      seed: () {
        final file = File(
          '${Directory.systemTemp.path}/payment_cubit_test_proof.jpg',
        )..writeAsBytesSync([1, 2, 3]);
        return PaymentState(pickedImagePath: file.path);
      },
      act: (cubit) => cubit.submitPayment(),
      verify: (cubit) async {
        final path = File(
          '${Directory.systemTemp.path}/payment_cubit_test_proof.jpg',
        );
        expect(await path.exists(), isFalse);
        expect(cubit.state.step, PaymentStep.review);
        expect(cubit.state.pickedImagePath, isNull);
      },
    );

    blocTest<PaymentCubit, PaymentState>(
      'a cleanup failure never blocks a payment that already succeeded '
      'server-side',
      setUp: () {
        when(() => repository.sendPayment(any())).thenAnswer(
          (_) async => const Ok(null),
        );
      },
      build: build,
      // A path that never existed — cleanup's File.exists() check makes
      // this a no-op rather than a thrown exception, but this proves the
      // flow still reaches PaymentStep.review either way.
      seed: () => const PaymentState(
        pickedImagePath: '/nonexistent/path/proof.jpg',
      ),
      act: (cubit) => cubit.submitPayment(),
      verify: (cubit) {
        expect(cubit.state.step, PaymentStep.review);
      },
    );
  });

  group('PaymentCubit.disconnectSocket — approved fix', () {
    // `blocTest` always calls `close()` on the built cubit at the end of
    // the test, which itself calls `disconnectSocket()` again — a real
    // repository would then return null (already cleared), so the mock
    // is made stateful here to match that, rather than asserting an
    // exact call count that's an artifact of blocTest's teardown.
    blocTest<PaymentCubit, PaymentState>(
      'always unsubscribes and clears the stored channel, even while on '
      'the review step — no exception like the old app had, which left a '
      'channel subscription alive in the shared gateway with nothing left '
      'listening to it',
      setUp: () {
        String? storedChannel = 'conf.27';
        when(
          () => repository.getPsychologistId(),
        ).thenAnswer((_) async => storedChannel);
        when(() => repository.clearPsychologistId()).thenAnswer((_) async {
          storedChannel = null;
        });
      },
      build: build,
      seed: () => const PaymentState(step: PaymentStep.review),
      act: (cubit) => cubit.disconnectSocket(),
      verify: (_) {
        expect(gateway.unsubscribedChannels, ['conf.27']);
        verify(() => repository.clearPsychologistId()).called(1);
      },
    );

    blocTest<PaymentCubit, PaymentState>(
      'also unsubscribes on a non-review step, for symmetry',
      setUp: () {
        String? storedChannel = 'conf.27';
        when(
          () => repository.getPsychologistId(),
        ).thenAnswer((_) async => storedChannel);
        when(() => repository.clearPsychologistId()).thenAnswer((_) async {
          storedChannel = null;
        });
      },
      build: build,
      seed: () => const PaymentState(step: PaymentStep.payment),
      act: (cubit) => cubit.disconnectSocket(),
      verify: (_) {
        expect(gateway.unsubscribedChannels, ['conf.27']);
        verify(() => repository.clearPsychologistId()).called(1);
      },
    );
  });
}
