import 'package:core/core.dart';
import 'package:test/test.dart';

class _DoubleUseCase extends UseCase<int, int> {
  @override
  Future<Result<Failure, int>> call(int params) async {
    if (params < 0) return const Err(ValidationFailure('must be positive'));
    return Ok(params * 2);
  }
}

void main() {
  group('UseCase', () {
    final useCase = _DoubleUseCase();

    test('returns Ok on valid params', () async {
      final result = await useCase(4);

      expect(result.isOk, isTrue);
      expect((result as Ok<Failure, int>).value, 8);
    });

    test('returns Err on invalid params', () async {
      final result = await useCase(-1);

      expect(result.isErr, isTrue);
      expect((result as Err<Failure, int>).failure, isA<ValidationFailure>());
    });

    test('NoParams is a valueless marker', () {
      expect(const NoParams(), isA<NoParams>());
    });
  });
}
