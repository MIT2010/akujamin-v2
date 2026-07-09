import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('Result', () {
    test('Ok carries the success value', () {
      const result = Ok<String, int>(42);

      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      expect(result.value, 42);
    });

    test('Err carries the failure value', () {
      const result = Err<String, int>('boom');

      expect(result.isErr, isTrue);
      expect(result.isOk, isFalse);
      expect(result.failure, 'boom');
    });

    test('fold calls onSuccess for Ok', () {
      const result = Ok<String, int>(1);

      final folded = result.fold((f) => 'error: $f', (v) => 'value: $v');

      expect(folded, 'value: 1');
    });

    test('fold calls onError for Err', () {
      const result = Err<String, int>('nope');

      final folded = result.fold((f) => 'error: $f', (v) => 'value: $v');

      expect(folded, 'error: nope');
    });
  });
}
