/// First-launch intro carousel — second migrated feature
/// (MIGRATION_LOG.md). Local-only (`shared_preferences`), no network:
/// proves the local-storage repository layer (a tier `about`/
/// `feature_profile`/`feature_home` never touched) and confirms the "no
/// UseCase" pass-through case a second time. The write-path +
/// UseCase-on-a-real-network-write test stays open — see MIGRATION_LOG.md.
library;

export 'src/data/datasources/first_launch_gate_adapter.dart';
export 'src/data/datasources/onboarding_local_datasource.dart';
export 'src/data/repositories/onboarding_repository_impl.dart';
export 'src/domain/repositories/onboarding_repository.dart';
export 'src/presentation/cubit/onboarding_cubit.dart';
export 'src/presentation/cubit/onboarding_state.dart';
export 'src/presentation/pages/onboarding_page.dart';
