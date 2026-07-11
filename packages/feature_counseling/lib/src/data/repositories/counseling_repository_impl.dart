import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/counseling_session.dart';
import '../../domain/repositories/counseling_repository.dart';
import '../datasources/counseling_remote_datasource.dart';
import '../models/counseling_session_model.dart';

/// §20 — converts the remote envelope into domain [CounselingSession]
/// entities. No local datasource, no cache (§11 doesn't apply — read-only
/// list, same "pure CRUD, no offline flow" shape as `AboutRepositoryImpl`).
///
/// `/chat/list`'s response envelope key is **`data`, not `datas`** —
/// confirmed by reading the old app's `CounselingRepositoryImpl` in full,
/// not assumed from `about`/`history`'s shape (which do use `datas`). A
/// real inconsistency in the old API across endpoints, not a typo here.
@LazySingleton(as: CounselingRepository)
class CounselingRepositoryImpl implements CounselingRepository {
  final CounselingRemoteDataSource _remote;
  CounselingRepositoryImpl(this._remote);

  @override
  Future<Result<Failure, List<CounselingSession>>> getSessions() async {
    final result = await _remote.getSessions();

    return result.fold(Err.new, (envelope) {
      if (envelope['status'] != 'ok') {
        return Err(
          ServerFailure(
            envelope['message'] as String? ?? 'Gagal memuat sesi konseling',
          ),
        );
      }

      final data = envelope['data'] as List;
      return Ok(
        data
            .map(
              (e) => CounselingSessionModel.fromJson(
                e as Map<String, dynamic>,
              ).toEntity(),
            )
            .toList(),
      );
    });
  }
}
