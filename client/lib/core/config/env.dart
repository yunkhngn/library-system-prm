/// Build-time configuration, passed with `--dart-define=API_BASE_URL=...`.
abstract final class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  static String get wsUrl {
    final uri = Uri.parse(apiBaseUrl);
    return uri.replace(scheme: uri.scheme == 'https' ? 'wss' : 'ws', path: '/ws').toString();
  }
}
