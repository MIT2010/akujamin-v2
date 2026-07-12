/// Psychological test-taking flow — migrated from the old app's `test`
/// feature. This slice covers only the camera/proctoring prerequisite;
/// see this package's pubspec description and MIGRATION_LOG.md for the
/// rest of the migration plan.
library;

export 'src/data/datasources/camera_image_jpeg_converter.dart';
export 'src/data/datasources/face_detector_datasource.dart';
export 'src/data/datasources/face_match_datasource.dart';
export 'src/data/models/face_match_result_model.dart';
export 'src/data/repositories/proctoring_gateway_impl.dart';
export 'src/domain/entities/attention_status.dart';
export 'src/domain/entities/face_match_result.dart';
export 'src/domain/entities/proctoring_event.dart';
export 'src/domain/repositories/proctoring_gateway.dart';
export 'src/presentation/cubit/proctoring_cubit.dart';
export 'src/presentation/cubit/proctoring_state.dart';
