/// Psychological test-taking flow — migrated from the old app's `test`
/// feature. See this package's pubspec description and MIGRATION_LOG.md
/// for the full migration plan.
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

// Question/answer flow, added alongside the camera/proctoring slice above.
export 'src/data/datasources/test_remote_datasource.dart';
export 'src/data/models/answer_model.dart';
export 'src/data/models/intro_model.dart';
export 'src/data/models/question_model.dart';
export 'src/data/models/section_model.dart';
export 'src/data/models/sub_item_model.dart';
export 'src/data/models/test_model.dart';
export 'src/data/repositories/screenshot_gateway_impl.dart';
export 'src/data/repositories/test_repository_impl.dart';
export 'src/domain/entities/answer_entity.dart';
export 'src/domain/entities/intro_entity.dart';
export 'src/domain/entities/question_entity.dart';
export 'src/domain/entities/question_step.dart';
export 'src/domain/entities/section_entity.dart';
export 'src/domain/entities/sub_item_entity.dart';
export 'src/domain/entities/test_entity.dart';
export 'src/domain/entities/test_type.dart';
export 'src/domain/repositories/screenshot_gateway.dart';
export 'src/domain/repositories/test_repository.dart';
export 'src/presentation/cubit/test_cubit.dart';
export 'src/presentation/cubit/test_state.dart';
export 'src/presentation/pages/result_page.dart';
export 'src/presentation/pages/test_page.dart';
