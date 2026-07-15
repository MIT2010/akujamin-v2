/// Compile-time `--dart-define` reader (§15, §31). Never hardcode a base
/// URL in feature code — always read `Env.current`.
enum Flavor { dev, staging, prod }

/// Pure, unit-testable on its own — see [Env.apiUrl]. Always includes the
/// `/api` prefix (confirmed against a real backend, 2026-07-14 —
/// `<base>/api/<path>` resolves, `<base>/v1/<path>` and
/// `<base>/api/v1/<path>` both 404): every project built from this kit so
/// far talks to a Laravel-style backend that routes everything under
/// `/api`, versioned or not. `apiVersion` is appended as an *extra*
/// segment only when non-empty, so this same code works unchanged for a
/// backend with no versioning concept (leave `API_VERSION` blank in
/// `flavors/<flavor>.json`) and one that has it (set `API_VERSION` to
/// whatever segment it expects, e.g. `v1`) — a `flavors/*.json` edit, not
/// a code change, is what switches between the two.
String joinApiUrl(String baseUrl, String apiVersion) =>
    apiVersion.isEmpty ? '$baseUrl/api' : '$baseUrl/api/$apiVersion';

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
  // Blank by default, not 'v1' — a version segment is opt-in per backend,
  // not assumed. See joinApiUrl's doc comment.
  static const _apiVersion = String.fromEnvironment(
    'API_VERSION',
    defaultValue: '',
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

  /// Base URL every API call is made against, e.g.
  /// `https://api.dev.example.com/api` (no `API_VERSION` set) or
  /// `https://api.dev.example.com/api/v1` (`API_VERSION=v1`).
  String get apiUrl => joinApiUrl(apiBaseUrl, apiVersion);

  bool get isDev => flavor == Flavor.dev;
  bool get isStaging => flavor == Flavor.staging;
  bool get isProd => flavor == Flavor.prod;

  /// `ws` in dev/staging, `wss` in prod — same scheme rule the old app used
  /// (`Env.environment == 'PRODUCTION' ? 'wss' : 'ws'`), rebased onto this
  /// kit's own `Flavor` enum instead of a raw string compare.
  String get wsScheme => isProd ? 'wss' : 'ws';
}
