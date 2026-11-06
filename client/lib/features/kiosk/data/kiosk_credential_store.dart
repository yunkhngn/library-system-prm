import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

typedef KioskCredentials = ({String code, String credential});

/// Remembers the device login so a reload or an expired kiosk token
/// (1 hour, no refresh) reconnects without staff re-entering the key.
class KioskCredentialStore {
  KioskCredentialStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _codeKey = 'kiosk_code';
  static const _credentialKey = 'kiosk_credential';
  final FlutterSecureStorage _storage;

  Future<KioskCredentials?> read() async {
    try {
      final code = await _storage.read(key: _codeKey);
      final credential = await _storage.read(key: _credentialKey);
      if (code == null || credential == null) return null;
      return (code: code, credential: credential);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(KioskCredentials value) async {
    try {
      await _storage.write(key: _codeKey, value: value.code);
      await _storage.write(key: _credentialKey, value: value.credential);
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _codeKey);
      await _storage.delete(key: _credentialKey);
    } catch (_) {}
  }
}

final kioskCredentialStoreProvider =
    Provider<KioskCredentialStore>((ref) => KioskCredentialStore());
