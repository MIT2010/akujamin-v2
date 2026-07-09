/// Usage anywhere in feature code: `if (getIt<FeatureFlags>().isEnabled(...))`
/// (§25).
abstract class FeatureFlags {
  bool isEnabled(String key);
}

/// Backed today by a plain map (i.e. every flag behaves as a no-op/off
/// unless explicitly turned on). Swapping to a real remote-config-backed
/// source later means implementing this interface once — zero changes
/// anywhere flags are *read*.
///
/// Registered per-`@Environment` in `RegisterModule`, not annotated here
/// directly — `dev`/`staging`/`prod` each get their own instance of this
/// same class with different seed flags.
class LocalFeatureFlags implements FeatureFlags {
  final Map<String, bool> _flags;

  const LocalFeatureFlags() : _flags = const {};

  const LocalFeatureFlags.withFlags(this._flags);

  @override
  bool isEnabled(String key) => _flags[key] ?? false;
}
