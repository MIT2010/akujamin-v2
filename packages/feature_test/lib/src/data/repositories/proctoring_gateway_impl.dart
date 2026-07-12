import 'dart:async';

import 'package:camera/camera.dart';
import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:shared/shared.dart';

import '../../domain/entities/attention_status.dart';
import '../../domain/entities/face_match_result.dart';
import '../../domain/entities/proctoring_event.dart';
import '../../domain/repositories/proctoring_gateway.dart';
import '../datasources/camera_image_jpeg_converter.dart';
import '../datasources/face_detector_datasource.dart';
import '../datasources/face_match_datasource.dart';

/// Mirrors the old app's `CameraRepositoryImpl` — same 4 FPS throttle on
/// local face detection (~250ms, confirmed already present in the old
/// app, not a new addition here) and the same independent 250ms periodic
/// face-match timer, gated on `attentive` + not-already-matching.
///
/// **Approved fixes** (MIGRATION_LOG.md's camera prerequisite audit):
/// `initialize()`'s [Result] is checked explicitly and emits
/// [CameraUnavailableEvent] on failure — the old app awaited
/// `camera.initialize()` with no try/catch inside an `async*` generator
/// with no `onError` listener anywhere downstream, so a permission denial
/// or missing-front-camera failure vanished silently (proctoring just
/// never started, with no indication why). That gap is closed here by
/// construction: every path through `startDetection()` either reaches
/// the image-stream setup or emits a `CameraUnavailableEvent` — there is
/// no third option that silently does neither.
@LazySingleton(as: ProctoringGateway)
class ProctoringGatewayImpl implements ProctoringGateway {
  ProctoringGatewayImpl(this._camera, this._faceDetector, this._faceMatch);

  final CameraGateway _camera;
  final FaceDetectorDatasource _faceDetector;
  final FaceMatchDatasource _faceMatch;

  StreamController<ProctoringEvent>? _controller;
  StreamSubscription<CameraImage>? _cameraSub;
  StreamSubscription? _matchSub;
  CameraImage? _latestFrame;
  bool _isProcessing = false;
  bool _isMatching = false;
  bool _isDisposed = false;
  final _throttle = Stopwatch();
  AttentionStatus? _lastDetection;

  @override
  Stream<ProctoringEvent> startDetection() async* {
    _isDisposed = false;
    _controller = StreamController<ProctoringEvent>.broadcast();

    final initResult = await _camera.initialize(
      CameraConfig(
        lensDirection: CameraLensDirection.front,
        resolutionPreset: ResolutionPreset.low,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      ),
    );

    if (initResult case Err(:final failure)) {
      _controller!.add(CameraUnavailableEvent(failure as CameraFailure));
      yield* _controller!.stream;
      return;
    }

    final controller = _camera.controller;
    if (controller == null || !_camera.isInitialized) {
      _controller!.add(
        const CameraUnavailableEvent(
          CameraFailure(
            CameraFailureReason.permissionDenied,
            'Kamera tidak dapat digunakan.',
          ),
        ),
      );
      yield* _controller!.stream;
      return;
    }

    final imageController = StreamController<CameraImage>.broadcast();
    await controller.startImageStream((image) => imageController.add(image));

    _throttle.start();

    _cameraSub = imageController.stream.listen((image) async {
      if (_isDisposed) return;

      _latestFrame = image;

      // 4 FPS throttling (~250ms) — same cadence as the old app.
      if (_throttle.elapsedMilliseconds < 250) return;
      if (_isProcessing) return;

      _throttle.reset();
      _isProcessing = true;

      try {
        final count = await _faceDetector.detectFaces(
          image,
          controller.description,
        );

        final status = switch (count) {
          0 => AttentionStatus.noFace,
          1 => AttentionStatus.attentive,
          _ => AttentionStatus.multipleFaces,
        };

        _lastDetection = status;

        if (!_isDisposed && !_controller!.isClosed) {
          _controller!.add(FaceDetectedEvent(status));
        }
      } catch (_) {
        // Frame-level detection errors are skipped, same as the old app —
        // one missed frame at 4 FPS isn't worth surfacing as a violation.
      } finally {
        _isProcessing = false;
      }
    });

    _startMatch();

    yield* _controller!.stream;
  }

  void _startMatch() {
    if (_matchSub != null) return;

    _matchSub = Stream.periodic(const Duration(milliseconds: 250)).listen((
      _,
    ) async {
      if (_isDisposed ||
          _latestFrame == null ||
          _isMatching ||
          _lastDetection != AttentionStatus.attentive) {
        return;
      }

      _isMatching = true;

      try {
        final bytes = convertCameraImageToJpeg(_latestFrame!);
        final result = await _faceMatch.match(bytes);

        if (_isDisposed || _controller!.isClosed) return;

        result.fold(
          (_) => _controller!.add(
            const FaceMatchedEvent(
              FaceMatchResult(status: FaceMatchStatus.error),
            ),
          ),
          (matchResult) => _controller!.add(FaceMatchedEvent(matchResult)),
        );
      } catch (_) {
        if (!_isDisposed && !_controller!.isClosed) {
          _controller!.add(
            const FaceMatchedEvent(
              FaceMatchResult(status: FaceMatchStatus.error),
            ),
          );
        }
      } finally {
        _isMatching = false;
      }
    });
  }

  @override
  Future<void> stopDetection() async {
    if (_isDisposed) return;
    _isDisposed = true;

    await _matchSub?.cancel();
    await _cameraSub?.cancel();
    _matchSub = null;
    _cameraSub = null;

    await _faceDetector.dispose();
    await _camera.dispose();

    await _controller?.close();
    _controller = null;

    _throttle.stop();
  }
}
