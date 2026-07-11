/// Compile-time `--dart-define` reader (§15, §31). Never hardcode a base
/// URL in feature code — always read `Env.current`.
enum Flavor { dev, staging, prod }

class Env {
  final Flavor flavor;
  final String apiBaseUrl;
  final String apiVersion;
  final String wsHost;
  final String wsPort;
  final String wsKey;

  const Env._({
    required this.flavor,
    required this.apiBaseUrl,
    required this.apiVersion,
    required this.wsHost,
    required this.wsPort,
    required this.wsKey,
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
  // Websocket (Pusher-protocol) config — added for feature_counseling, will
  // be shared by any future feature that also needs realtime (§1 "extract
  // once": kept as plain Env fields, not a separate config class, until a
  // second consumer proves one is worth it).
  static const _wsHost = String.fromEnvironment('WS_HOST');
  static const _wsPort = String.fromEnvironment('WS_PORT', defaultValue: '80');
  static const _wsKey = String.fromEnvironment('WS_KEY');

  static final Env current = Env._(
    flavor: Flavor.values.firstWhere(
      (f) => f.name == _flavorName,
      orElse: () => Flavor.dev,
    ),
    apiBaseUrl: _apiBaseUrl,
    apiVersion: _apiVersion,
    wsHost: _wsHost,
    wsPort: _wsPort,
    wsKey: _wsKey,
  );

  /// Base URL pinned to the API version, e.g. `https://api.dev.example.com/v1`.
  String get apiUrl => '$apiBaseUrl/$apiVersion';

  bool get isDev => flavor == Flavor.dev;
  bool get isStaging => flavor == Flavor.staging;
  bool get isProd => flavor == Flavor.prod;

  /// `ws` in dev/staging, `wss` in prod — same scheme rule the old app used
  /// (`Env.environment == 'PRODUCTION' ? 'wss' : 'ws'`), rebased onto this
  /// kit's own `Flavor` enum instead of a raw string compare.
  String get wsScheme => isProd ? 'wss' : 'ws';
}
