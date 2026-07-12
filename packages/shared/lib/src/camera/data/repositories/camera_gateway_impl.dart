import 'package:camera/camera.dart';
import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/camera_config.dart';
import '../../domain/repositories/camera_gateway.dart';
import '../datasources/camera_datasource.dart';

/// Approved fix (MIGRATION_LOG.md's camera prerequisite audit): the old
/// app's `CameraDatasourceImpl` silently substituted whatever camera was
/// available (`cameras.firstWhere(..., orElse: () => cameras.first)`) when
/// the requested lens direction wasn't found, and let a genuinely
/// camera-less device throw an uncaught `StateError`. Both are real
/// correctness bugs, not just missing polish — for `test`'s proctoring
/// specifically, silently analyzing the wrong camera's feed invalidates
/// the entire mechanism without anyone knowing. This gateway never
/// substitutes; every failure mode gets its own [CameraFailureReason] so
/// each caller can react appropriately instead of one behavior being
/// forced on every consumer.
@LazySingleton(as: CameraGateway)
class CameraGatewayImpl implements CameraGateway {
  final CameraDatasource _datasource;
  CameraGatewayImpl(this._datasource);

  @override
  Future<Result<Failure, void>> initialize(CameraConfig config) async {
    try {
      final cameras = await _datasource.availableCameras();

      if (cameras.isEmpty) {
        return const Err(
          CameraFailure(
            CameraFailureReason.noCameraOnDevice,
            'Perangkat ini tidak memiliki kamera.',
          ),
        );
      }

      final matches = cameras.where(
        (c) => c.lensDirection == config.lensDirection,
      );

      if (matches.isEmpty) {
        return const Err(
          CameraFailure(
            CameraFailureReason.requestedLensNotFound,
            'Kamera yang diminta tidak tersedia di perangkat ini.',
          ),
        );
      }

      await _datasource.initialize(matches.first, config);
      return const Ok(null);
    } on CameraException catch (e) {
      return Err(
        CameraFailure(
          CameraFailureReason.permissionDenied,
          e.description ?? 'Akses kamera ditolak.',
        ),
      );
    } catch (e) {
      return Err(
        CameraFailure(CameraFailureReason.permissionDenied, e.toString()),
      );
    }
  }

  @override
  Future<Result<Failure, String>> captureImage() async {
    try {
      final path = await _datasource.captureImage();
      return Ok(path);
    } catch (e) {
      return Err(
        CameraFailure(CameraFailureReason.captureFailed, e.toString()),
      );
    }
  }

  @override
  Future<void> dispose() => _datasource.dispose();

  @override
  bool get isInitialized => _datasource.isInitialized;

  @override
  CameraController? get controller => _datasource.controller;
}
