import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('Env', () {
    test('defaults to the dev flavor when no --dart-define is passed', () {
      expect(Env.current.flavor, Flavor.dev);
      expect(Env.current.isDev, isTrue);
      expect(Env.current.isStaging, isFalse);
      expect(Env.current.isProd, isFalse);
    });

    test('apiUrl pins the base URL to the configured API version', () {
      expect(
        Env.current.apiUrl,
        '${Env.current.apiBaseUrl}/${Env.current.apiVersion}',
      );
      expect(Env.current.apiUrl, endsWith('/v1'));
    });
  });
}
