import 'package:shared/shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NoopCrashReporter', () {
    final reporter = NoopCrashReporter();

    test('recordError completes without throwing', () async {
      await expectLater(
        reporter.recordError(
          Exception('boom'),
          StackTrace.current,
          fatal: true,
        ),
        completes,
      );
    });

    test('setUserId completes without throwing', () async {
      await expectLater(reporter.setUserId('user-1'), completes);
    });
  });
}
