import 'package:core/core.dart';
import 'package:feature_{{feature_name.snakeCase()}}/feature_{{feature_name.snakeCase()}}.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Mock{{feature_name.pascalCase()}}RemoteDataSource extends Mock
    implements {{feature_name.pascalCase()}}RemoteDataSource {}

void main() {
  late _Mock{{feature_name.pascalCase()}}RemoteDataSource remote;
  late {{feature_name.pascalCase()}}RepositoryImpl repository;

  // TODO: extend with this feature's real fields once the entity has them.
  const model = {{feature_name.pascalCase()}}Model(id: '1');

  setUp(() {
    remote = _Mock{{feature_name.pascalCase()}}RemoteDataSource();
    repository = {{feature_name.pascalCase()}}RepositoryImpl(remote);
  });

  group('{{feature_name.pascalCase()}}RepositoryImpl.get{{feature_name.pascalCase()}}', () {
    test('returns Ok with the mapped entity on success', () async {
      when(() => remote.get{{feature_name.pascalCase()}}())
          .thenAnswer((_) async => const Ok(model));

      final result = await repository.get{{feature_name.pascalCase()}}();

      expect(result.isOk, isTrue);
      // TODO: assert this feature's real fields once they exist.
      expect((result as Ok<Failure, {{feature_name.pascalCase()}}>).value.id, '1');
    });

    test('returns Err on a server failure', () async {
      when(() => remote.get{{feature_name.pascalCase()}}()).thenAnswer(
        (_) async =>
            const Err(ServerFailure('Internal error', statusCode: 500)),
      );

      final result = await repository.get{{feature_name.pascalCase()}}();

      expect(result.isErr, isTrue);
      expect(
        (result as Err<Failure, {{feature_name.pascalCase()}}>).failure,
        isA<ServerFailure>(),
      );
    });
  });
}
