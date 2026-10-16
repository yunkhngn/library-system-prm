import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// Access token lives in memory only; the refresh token is persisted so the
/// session survives an app restart.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _refreshKey = 'refresh_token';

  final FlutterSecureStorage _storage;
  String? accessToken;

  /// Unreadable storage (e.g. reset keystore) is treated as signed out.
  Future<String?> readRefreshToken() async {
    try {
      return await _storage.read(key: _refreshKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> save({required String accessToken, required String refreshToken}) async {
    this.accessToken = accessToken;
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<void> clear() async {
    accessToken = null;
    await _storage.delete(key: _refreshKey);
  }
}
