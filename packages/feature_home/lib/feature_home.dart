/// The home feed feature (§5) — first feature exercising the §11 offline
/// cache flow (Hive CE read-through/write-through, stale-fallback on
/// network failure only).
library;

export 'src/data/datasources/home_local_datasource.dart';
export 'src/data/datasources/home_remote_datasource.dart';
export 'src/data/models/home_item_model.dart';
export 'src/data/repositories/home_repository_impl.dart';
export 'src/di/register_module.dart';
export 'src/domain/entities/home_feed.dart';
export 'src/domain/entities/home_item.dart';
export 'src/domain/repositories/home_repository.dart';
export 'src/presentation/cubit/home_cubit.dart';
export 'src/presentation/cubit/home_state.dart';
export 'src/presentation/pages/home_page.dart';
