import 'host_platform.dart';

/// Build-time configuration, passed with `--dart-define=API_BASE_URL=...`.
abstract final class Env {
  static const _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// The Android emulator reaches the host machine through `10.0.2.2`;
  /// `localhost` there is the emulator itself. Physical devices still need
  /// `API_BASE_URL` pointing at the host's LAN IP.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    return runsOnAndroid ? 'http://10.0.2.2:8080' : 'http://localhost:8080';
  }

  static String get wsUrl {
    final uri = Uri.parse(apiBaseUrl);
    return uri.replace(scheme: uri.scheme == 'https' ? 'wss' : 'ws', path: '/ws').toString();
  }
}
