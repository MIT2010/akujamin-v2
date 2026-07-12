import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:feature_test/feature_test.dart';
import 'package:flutter_test/flutter_test.dart';

/// A controllable fake, not a mock — same reasoning as
/// `feature_counseling`'s `_FakeSocketGateway`: needs a real stream to
/// push fabricated events into and real call-history assertions for
/// `stopDetection()`.
class _FakeProctoringGateway implements ProctoringGateway {
  final _controller = StreamController<ProctoringEvent>.broadcast();
  int stopDetectionCalls = 0;

  @override
  Stream<ProctoringEvent> startDetection() => _controller.stream;

  @override
  Future<void> stopDetection() async {
    stopDetectionCalls++;
  }

  void emit(ProctoringEvent event) => _controller.add(event);

  void emitError(Object error) => _controller.addError(error);

  Future<void> dispose() => _controller.close();
}

/// A mutable fake clock — advanced explicitly per test instead of using
/// real `Future.delayed` waits, so the 2s grace-period / 10s
/// violation-threshold logic can be proven exactly without a genuinely
/// slow test suite.
class _FakeClock {
  DateTime _now = DateTime(2026);

  DateTime call() => _now;

  void advance(Duration by) => _now = _now.add(by);
}

void main() {
  late _FakeProctoringGateway gateway;
  late _FakeClock clock;

  setUp(() {
    gateway = _FakeProctoringGateway();
    clock = _FakeClock();
  });

  tearDown(() => gateway.dispose());

  ProctoringCubit build() => ProctoringCubit(gateway, clock: clock.call);

  group('ProctoringCubit — face detection / grace period / violation', () {
    blocTest<ProctoringCubit, ProctoringState>(
      'a noFace event before the grace period elapses shows no warning yet',
      build: build,
      act: (cubit) {
        cubit.start();
        gateway.emit(const FaceDetectedEvent(AttentionStatus.noFace));
      },
      expect: () => [
        isA<ProctoringDetecting>()
            .having((s) => s.status, 'status', AttentionStatus.noFace)
            .having((s) => s.showWarning, 'showWarning', isFalse)
            .having((s) => s.isViolation, 'isViolation', isFalse),
      ],
    );

    blocTest<ProctoringCubit, ProctoringState>(
      'showWarning flips true once the clock passes the 2s grace period, '
      'isViolation stays false — the threshold has not been reached yet',
      build: build,
      act: (cubit) async {
        cubit.start();
        gateway.emit(const FaceDetectedEvent(AttentionStatus.noFace));
        await Future(() {});
        clock.advance(const Duration(seconds: 2, milliseconds: 1));
        gateway.emit(const FaceDetectedEvent(AttentionStatus.noFace));
        await Future(() {});
      },
      skip: 1,
      expect: () => [
        isA<ProctoringDetecting>()
            .having((s) => s.showWarning, 'showWarning', isTrue)
            .having((s) => s.isViolation, 'isViolation', isFalse)
            .having((s) => s.error, 'error', 'Wajah tidak terdeteksi.'),
      ],
    );

    blocTest<ProctoringCubit, ProctoringState>(
      'isViolation flips true once the clock passes the 10s violation '
      'threshold, measured from when the violation first started — not '
      'from the most recent event',
      build: build,
      act: (cubit) async {
        cubit.start();
        gateway.emit(const FaceDetectedEvent(AttentionStatus.noFace));
        await Future(() {});
        clock.advance(const Duration(seconds: 10, milliseconds: 1));
        gateway.emit(const FaceDetectedEvent(AttentionStatus.noFace));
        await Future(() {});
      },
      skip: 1,
      expect: () => [
        isA<ProctoringDetecting>()
            .having((s) => s.isViolation, 'isViolation', isTrue)
            .having((s) => s.showWarning, 'showWarning', isTrue),
      ],
    );

    blocTest<ProctoringCubit, ProctoringState>(
      'returning to attentive resets violationDuration and clears the '
      'timer for the next violation window',
      build: build,
      act: (cubit) async {
        cubit.start();
        gateway.emit(const FaceDetectedEvent(AttentionStatus.noFace));
        await Future(() {});
        clock.advance(const Duration(seconds: 5));
        gateway.emit(const FaceDetectedEvent(AttentionStatus.attentive));
        await Future(() {});
      },
      skip: 1,
      expect: () => [
        isA<ProctoringDetecting>()
            .having((s) => s.status, 'status', AttentionStatus.attentive)
            .having((s) => s.violationDuration, 'violationDuration', Duration.zero)
            // matchStatus is still unknown at this point, so per the
            // "attentive but not yet matched" rule this is still flagged.
            .having((s) => s.isViolation, 'isViolation', isTrue),
      ],
    );
  });

  group('ProctoringCubit — face match', () {
    blocTest<ProctoringCubit, ProctoringState>(
      'a matched result while attentive clears the "not yet matched" '
      'violation',
      build: build,
      seed: () => const ProctoringState.detecting(
        status: AttentionStatus.attentive,
        isViolation: true,
        showWarning: true,
      ),
      act: (cubit) {
        cubit.start();
        gateway.emit(
          const FaceMatchedEvent(
            FaceMatchResult(status: FaceMatchStatus.matched, confidence: 0.95),
          ),
        );
      },
      verify: (cubit) {
        final state = cubit.state as ProctoringDetecting;
        expect(state.matchStatus, FaceMatchStatus.matched);
        expect(state.isViolation, isFalse);
      },
    );

    blocTest<ProctoringCubit, ProctoringState>(
      'a notMatched result while attentive is itself a violation',
      build: build,
      seed: () => const ProctoringState.detecting(
        status: AttentionStatus.attentive,
      ),
      act: (cubit) {
        cubit.start();
        gateway.emit(
          const FaceMatchedEvent(FaceMatchResult(status: FaceMatchStatus.notMatched)),
        );
      },
      verify: (cubit) {
        expect((cubit.state as ProctoringDetecting).isViolation, isTrue);
      },
    );

    blocTest<ProctoringCubit, ProctoringState>(
      'a match result is ignored while the face is not currently attentive '
      '— matching a face that is not even in frame is meaningless',
      build: build,
      seed: () => const ProctoringState.detecting(
        status: AttentionStatus.noFace,
      ),
      act: (cubit) {
        cubit.start();
        gateway.emit(
          const FaceMatchedEvent(FaceMatchResult(status: FaceMatchStatus.matched)),
        );
      },
      expect: () => [],
    );
  });

  group('ProctoringCubit — approved fix: camera failures never vanish silently', () {
    blocTest<ProctoringCubit, ProctoringState>(
      'a CameraUnavailableEvent moves the cubit into a hard, permanent '
      'state carrying the specific failure reason — not folded into '
      'AttentionStatus the way the old app conflated it',
      build: build,
      act: (cubit) {
        cubit.start();
        gateway.emit(
          const CameraUnavailableEvent(
            CameraFailure(
              CameraFailureReason.requestedLensNotFound,
              'Kamera yang diminta tidak tersedia di perangkat ini.',
            ),
          ),
        );
      },
      expect: () => [
        const ProctoringState.cameraUnavailable(
          reason: CameraFailureReason.requestedLensNotFound,
          message: 'Kamera yang diminta tidak tersedia di perangkat ini.',
        ),
      ],
    );

    blocTest<ProctoringCubit, ProctoringState>(
      'an uncaught stream error (not even a CameraUnavailableEvent) still '
      'surfaces as a state change — the old app\'s .listen() had no '
      'onError at all, so this exact scenario left the UI silently stuck',
      build: build,
      act: (cubit) {
        cubit.start();
        gateway.emitError(Exception('unexpected'));
      },
      expect: () => [isA<ProctoringCameraUnavailable>()],
    );

    blocTest<ProctoringCubit, ProctoringState>(
      'detection/match events are ignored once the camera has failed — '
      'there is nothing meaningful left to transition through',
      build: build,
      seed: () => const ProctoringState.cameraUnavailable(
        reason: CameraFailureReason.noCameraOnDevice,
        message: 'Perangkat ini tidak memiliki kamera.',
      ),
      act: (cubit) {
        cubit.start();
        gateway.emit(const FaceDetectedEvent(AttentionStatus.attentive));
      },
      expect: () => [],
    );
  });

  group('ProctoringCubit.close', () {
    test('tears down the gateway on close', () async {
      final cubit = build();
      cubit.start();

      await cubit.close();

      expect(gateway.stopDetectionCalls, 1);
    });
  });
}
