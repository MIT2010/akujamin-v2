import 'package:shared/shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NoopAnalyticsService', () {
    final service = NoopAnalyticsService();

    test('logEvent completes without doing anything observable', () async {
      await expectLater(
        service.logEvent('login_success', params: {'method': 'password'}),
        completes,
      );
    });

    test('setUserId completes without doing anything observable', () async {
      await expectLater(service.setUserId('user-1'), completes);
    });
  });
}
