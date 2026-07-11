import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

/// Stores the psychologist ID selected during the demography step, so it
/// survives a socket disconnect/reconnect and app restart mid-flow.
///
/// **Fixes the ADR-011-class vulnerability found during the write-path
/// audit**: the old app's `PaymentLocalServiceImpl` used a bare,
/// unprefixed key (`static const String _key = 'psychologist';`) — on
/// Windows, `flutter_secure_storage`'s Credential Manager backing has no
/// per-app namespacing at all (confirmed by reading
/// `flutter_secure_storage_windows_plugin.cpp` during the `auth`
/// migration), so two different apps on the same machine both writing
/// key `'psychologist'` collide in the same global credential. This uses
/// the same prefix convention already established by `authentication`'s
/// `SecureTokenStorage` — fixed here, not ported.
@lazySingleton
class PaymentLocalDataSource {
  final FlutterSecureStorage _storage;
  PaymentLocalDataSource(this._storage);

  static const _keyPrefix = 'com.akujamin.mobile.';
  static const _psychologistIdKey = '${_keyPrefix}payment_psychologist_id';

  Future<String?> getPsychologistId() => _storage.read(key: _psychologistIdKey);

  Future<void> savePsychologistId(String id) =>
      _storage.write(key: _psychologistIdKey, value: id);

  Future<void> clearPsychologistId() =>
      _storage.delete(key: _psychologistIdKey);
}
