import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('Failure', () {
    test('ServerFailure carries message and status code', () {
      const failure = ServerFailure('Something broke', statusCode: 500);

      expect(failure.message, 'Something broke');
      expect(failure.statusCode, 500);
      expect(failure, isA<Failure>());
    });

    test('NetworkFailure has a fixed human-readable message', () {
      const failure = NetworkFailure();

      expect(failure.message, 'No internet connection');
    });

    test('UnauthorizedFailure has a fixed human-readable message', () {
      const failure = UnauthorizedFailure();

      expect(failure.message, 'Session expired');
    });

    test('CacheFailure and ValidationFailure carry their own message', () {
      const cache = CacheFailure('cache miss');
      const validation = ValidationFailure('email is required');

      expect(cache.message, 'cache miss');
      expect(validation.message, 'email is required');
    });
  });
}
