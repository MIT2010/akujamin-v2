import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/repositories/{{feature_name.snakeCase()}}_repository.dart';
import '{{feature_name.snakeCase()}}_state.dart';

/// Calls the repository directly — no UseCase, deliberately (§21/ADR-004):
/// a plain pass-through has no orchestration to name.
///
/// TODO: if a method here ever grows real orchestration (analytics,
/// combining repositories, a business rule), promote THAT method — and
/// only that method — to a UseCase. Read §21 of ARCHITECTURE.md first;
/// `feature_profile`'s UpdateProfileUseCase is the reference for a
/// justified one. Don't add one reflexively.
///
/// `core` is imported directly (not just transitively via the repository)
/// because `Result.fold` is an extension method — those need the extension
/// itself in scope, not just the type it applies to (§15).
@injectable
class {{feature_name.pascalCase()}}Cubit extends Cubit<{{feature_name.pascalCase()}}State> {
  final {{feature_name.pascalCase()}}Repository _repository;

  {{feature_name.pascalCase()}}Cubit(this._repository)
    : super(const {{feature_name.pascalCase()}}State.initial());

  Future<void> get{{feature_name.pascalCase()}}() async {
    emit(const {{feature_name.pascalCase()}}State.loading());
    final result = await _repository.get{{feature_name.pascalCase()}}();
    result.fold(
      (failure) => emit({{feature_name.pascalCase()}}State.error(failure)),
      ({{feature_name.camelCase()}}) =>
          emit({{feature_name.pascalCase()}}State.loaded({{feature_name.camelCase()}})),
    );
  }
}
