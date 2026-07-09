/// Compile-time `--dart-define` reader (§15, §31). Never hardcode a base
/// URL in feature code — always read `Env.current`.
enum Flavor { dev, staging, prod }

class Env {
  final Flavor flavor;
  final String apiBaseUrl;
  final String apiVersion;

  const Env._({
    required this.flavor,
    required this.apiBaseUrl,
    required this.apiVersion,
  });

  static const _flavorName = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'dev',
  );
  static const _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.dev.example.com',
  );
  static const _apiVersion = String.fromEnvironment(
    'API_VERSION',
    defaultValue: 'v1',
  );

  static final Env current = Env._(
    flavor: Flavor.values.firstWhere(
      (f) => f.name == _flavorName,
      orElse: () => Flavor.dev,
    ),
    apiBaseUrl: _apiBaseUrl,
    apiVersion: _apiVersion,
  );

  /// Base URL pinned to the API version, e.g. `https://api.dev.example.com/v1`.
  String get apiUrl => '$apiBaseUrl/$apiVersion';

  bool get isDev => flavor == Flavor.dev;
  bool get isStaging => flavor == Flavor.staging;
  bool get isProd => flavor == Flavor.prod;
}
