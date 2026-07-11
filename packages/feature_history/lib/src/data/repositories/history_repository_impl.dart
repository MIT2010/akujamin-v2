import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/test_history_item.dart';
import '../../domain/repositories/history_repository.dart';
import '../datasources/history_remote_datasource.dart';
import '../models/test_history_item_model.dart';

/// §20 — converts the remote envelope into domain [TestHistoryItem]
/// entities. No local datasource, no cache (§11 doesn't apply — read-only
/// history, same "pure CRUD, no offline flow" shape as
/// `AboutRepositoryImpl`).
///
/// `/tes/list-voucher`'s response wraps its payload in the same
/// `{status, message, datas}` envelope as `/faq/get` — confirmed by reading
/// the old app's `PaymentRepositoryImpl.getVouchers()` in full, not
/// assumed from `about`'s shape.
@LazySingleton(as: HistoryRepository)
class HistoryRepositoryImpl implements HistoryRepository {
  final HistoryRemoteDataSource _remote;
  HistoryRepositoryImpl(this._remote);

  @override
  Future<Result<Failure, List<TestHistoryItem>>> getHistory() async {
    final result = await _remote.getHistory();

    return result.fold(Err.new, (envelope) {
      if (envelope['status'] != 'ok') {
        return Err(
          ServerFailure(
            envelope['message'] as String? ?? 'Gagal memuat riwayat tes',
          ),
        );
      }

      final datas = envelope['datas'] as List;
      return Ok(
        datas
            .map(
              (e) => TestHistoryItemModel.fromJson(
                e as Map<String, dynamic>,
              ).toEntity(),
            )
            .toList(),
      );
    });
  }
}
