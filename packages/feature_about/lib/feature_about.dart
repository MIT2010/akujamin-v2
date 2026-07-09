/// FAQ / About content — migration pilot, migrated from akujamin-app's
/// `about` feature (AUDIT.md §4, docs/MIGRATION_PLAYBOOK.md in the starter
/// kit this project was bootstrapped from). Read-only, no local cache: the
/// simplest possible full-stack feature, chosen specifically to prove the
/// migration recipe end-to-end before the larger features follow.
library;

export 'src/data/datasources/about_remote_datasource.dart';
export 'src/data/models/about_model.dart';
export 'src/data/repositories/about_repository_impl.dart';
export 'src/domain/entities/about.dart';
export 'src/domain/repositories/about_repository.dart';
export 'src/presentation/cubit/about_cubit.dart';
export 'src/presentation/cubit/about_state.dart';
export 'src/presentation/pages/about_page.dart';
