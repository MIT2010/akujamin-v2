import 'package:shared/shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalFeatureFlags', () {
    test('the default (DI-registered) constructor has every flag off', () {
      const flags = LocalFeatureFlags();

      expect(flags.isEnabled('new_checkout_flow'), isFalse);
    });

    test('withFlags reads from the provided map', () {
      const flags = LocalFeatureFlags.withFlags({'new_checkout_flow': true});

      expect(flags.isEnabled('new_checkout_flow'), isTrue);
      expect(flags.isEnabled('unrelated_flag'), isFalse);
    });
  });
}
