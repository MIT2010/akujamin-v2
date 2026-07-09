import 'package:hive_ce/hive_ce.dart';
import 'package:injectable/injectable.dart';

import '../models/home_item_model.dart';

/// §24's local-cache example, concretely: the read-through/write-through
/// cache §11's offline flow falls back to. The box itself is opened once,
/// in `RegisterModule` (§12: "@module → external deps ... Hive boxes"), so
/// this class only ever deals with an already-open [Box].
///
/// Keyed by [HomeItemModel.id] rather than one giant list under a single
/// key, so a future partial-update (e.g. one item changed) doesn't require
/// rewriting the whole cache.
@injectable
class HomeLocalDataSource {
  final Box<HomeItemModel> _box;
  HomeLocalDataSource(this._box);

  List<HomeItemModel> getCached() => _box.values.toList();

  Future<void> cacheItems(List<HomeItemModel> items) async {
    await _box.clear();
    await _box.putAll({for (final item in items) item.id: item});
  }
}
