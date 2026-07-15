import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('AppLogger', () {
    final logger = AppLogger();

    test('all log levels run without throwing', () {
      expect(() => logger.d('debug message'), returnsNormally);
      expect(() => logger.i('info message'), returnsNormally);
      expect(() => logger.w('warn message'), returnsNormally);
      expect(
        () => logger.e(
          'error message',
          error: Exception('boom'),
          stackTrace: StackTrace.current,
        ),
        returnsNormally,
      );
    });

    test('api() logs under the api channel without throwing', () {
      expect(() => logger.api('--> GET /ping'), returnsNormally);
    });
  });
}
