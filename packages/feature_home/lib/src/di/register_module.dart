import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:injectable/injectable.dart';

import '../data/models/hive_registrar.g.dart';
import '../data/models/home_item_model.dart';

/// External dep the local datasource needs (§12: "@module → external deps
/// ... Hive boxes"). `@preResolve` because opening a box is async and must
/// finish before `get_it` hands out [HomeLocalDataSource] — `feature_home`
/// is the first (and so far only) feature using Hive, so init/registration
/// lives here rather than in `core`/`shared`, which don't need it yet.
@module
abstract class RegisterModule {
  @preResolve
  Future<Box<HomeItemModel>> get homeItemsBox async {
    await Hive.initFlutter();
    Hive.registerAdapters();
    return Hive.openBox<HomeItemModel>('home_items');
  }
}
