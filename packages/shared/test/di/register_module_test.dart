import 'package:shared/shared.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestRegisterModule extends RegisterModule {}

void main() {
  group('RegisterModule feature flags (per @Environment)', () {
    final module = _TestRegisterModule();

    test('dev defaults the debug banner on', () {
      final flags = module.devFeatureFlags();

      expect(flags.isEnabled('debug_banner'), isTrue);
    });

    test('staging starts with every flag off', () {
      final flags = module.stagingFeatureFlags();

      expect(flags.isEnabled('debug_banner'), isFalse);
    });

    test('prod starts with every flag off', () {
      final flags = module.prodFeatureFlags();

      expect(flags.isEnabled('debug_banner'), isFalse);
    });
  });
}
