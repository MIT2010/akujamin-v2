import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/about.dart';
import '../../domain/repositories/about_repository.dart';
import '../datasources/about_remote_datasource.dart';
import '../models/about_model.dart';

/// §20 — converts the remote envelope into domain [About] entities. No
/// local datasource, no cache (§11 doesn't apply — read-only FAQ content,
/// same "pure CRUD, no offline flow" shape as `ProfileRepositoryImpl`).
///
/// The `/faq/get` response wraps its payload in an app-level
/// `{status, message, datas}` envelope — a *different* shape from `core`'s
/// generic `ApiResponse<T>` (`{success, message, data}`), so this repository
/// interprets it directly rather than forcing a field-name mismatch onto
/// the shared envelope type. This is exactly where the old app's
/// `AboutRepositoryImpl` did the same `status != 'ok'` check
/// (docs/MIGRATION_PLAYBOOK.md §2a/§2b) — kept in the same layer here, not
/// pushed down into the datasource, specifically so this logic stays
/// covered by the repository-level tests this kit's tests are written
/// against (mocking the datasource, not `ApiClient`/`Dio`).
@LazySingleton(as: AboutRepository)
class AboutRepositoryImpl implements AboutRepository {
  final AboutRemoteDataSource _remote;
  AboutRepositoryImpl(this._remote);

  @override
  Future<Result<Failure, List<About>>> getAbout() async {
    final result = await _remote.getAbout();

    return result.fold(Err.new, (envelope) {
      if (envelope['status'] != 'ok') {
        return Err(
          ServerFailure(envelope['message'] as String? ?? 'Gagal memuat FAQ'),
        );
      }

      final datas = envelope['datas'] as List;
      return Ok(
        datas
            .map(
              (e) => AboutModel.fromJson(e as Map<String, dynamic>).toEntity(),
            )
            .toList(),
      );
    });
  }
}
