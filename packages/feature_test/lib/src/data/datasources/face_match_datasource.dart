import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/face_match_result.dart';
import '../models/face_match_result_model.dart';

/// Migrated from `camera`'s `FaceMatchDatasourceImpl` — confirmed the
/// only live implementation of the two found calling
/// `/pertanyaan/face-matchv2` (MIGRATION_LOG.md's write-path audit;
/// `test`'s own `MatchFaceUsecase` chain was dead code, not ported).
/// Field name `'image'` and raw-JPEG-bytes shape kept exactly as the old
/// app sent them — not guessed.
@injectable
class FaceMatchDatasource {
  final ApiClient _client;
  FaceMatchDatasource(this._client);

  Future<Result<Failure, FaceMatchResult>> match(List<int> imageBytes) {
    return _client.multipart<FaceMatchResult>(
      '/pertanyaan/face-matchv2',
      data: FormData.fromMap({
        'image': MultipartFile.fromBytes(imageBytes, filename: 'frame.jpg'),
      }),
      parser: (json) => FaceMatchResultModel.fromJson(json as Map<String, dynamic>),
    );
  }
}
