import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  group('ReconnectBackoff', () {
    test('doubles each attempt starting from the base delay', () {
      final backoff = ReconnectBackoff(
        base: const Duration(seconds: 1),
        max: const Duration(seconds: 30),
      );

      expect(backoff.next(), const Duration(seconds: 1));
      expect(backoff.next(), const Duration(seconds: 2));
      expect(backoff.next(), const Duration(seconds: 4));
      expect(backoff.next(), const Duration(seconds: 8));
      expect(backoff.next(), const Duration(seconds: 16));
    });

    test('caps at max once the doubled delay would exceed it', () {
      final backoff = ReconnectBackoff(
        base: const Duration(seconds: 1),
        max: const Duration(seconds: 30),
      );

      for (var i = 0; i < 5; i++) {
        backoff.next(); // 1, 2, 4, 8, 16
      }

      expect(backoff.next(), const Duration(seconds: 30)); // would be 32
      expect(backoff.next(), const Duration(seconds: 30)); // stays capped
    });

    test('reset() restarts the sequence from the base delay', () {
      final backoff = ReconnectBackoff(
        base: const Duration(seconds: 1),
        max: const Duration(seconds: 30),
      );

      backoff.next();
      backoff.next();
      backoff.reset();

      expect(backoff.next(), const Duration(seconds: 1));
    });
  });
}
