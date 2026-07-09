/// User profile view/edit (§5) — second manual feature, deliberately
/// simpler than `feature_home`: pure CRUD against the API, no local cache.
library;

export 'src/data/datasources/profile_remote_datasource.dart';
export 'src/data/models/profile_model.dart';
export 'src/data/repositories/profile_repository_impl.dart';
export 'src/domain/entities/profile.dart';
export 'src/domain/repositories/profile_repository.dart';
export 'src/domain/usecases/update_profile_usecase.dart';
export 'src/presentation/cubit/profile_cubit.dart';
export 'src/presentation/cubit/profile_state.dart';
export 'src/presentation/pages/profile_page.dart';
