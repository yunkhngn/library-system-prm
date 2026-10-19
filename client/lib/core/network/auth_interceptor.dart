import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// Attaches the access token and transparently refreshes it once on 401.
///
/// [QueuedInterceptor] serializes error handling, so concurrent 401s trigger a
/// single refresh; later requests retry with the already-refreshed token.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required Dio dio,
    required TokenStorage tokens,
    required Future<bool> Function() refreshSession,
    required void Function() onSessionExpired,
  })  : _dio = dio,
        _tokens = tokens,
        _refreshSession = refreshSession,
        _onSessionExpired = onSessionExpired;

  static const skipAuthKey = 'skipAuth';

  /// Refresh authentication after a 401, but leave issuing a new QR to the user.
  static const noReplayKey = 'noReplay';
  static const _retriedKey = 'authRetried';

  final Dio _dio;
  final TokenStorage _tokens;
  final Future<bool> Function() _refreshSession;
  final void Function() _onSessionExpired;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokens.accessToken;
    if (options.extra[skipAuthKey] != true && token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final shouldRefresh = err.response?.statusCode == 401 &&
        options.extra[skipAuthKey] != true &&
        options.extra[_retriedKey] != true;
    if (!shouldRefresh) return handler.next(err);

    final sentToken = (options.headers['Authorization'] as String?)
        ?.replaceFirst('Bearer ', '');
    final alreadyRefreshed =
        sentToken != null && sentToken != _tokens.accessToken;

    if (!alreadyRefreshed && !await _refreshSession()) {
      _onSessionExpired();
      return handler.next(err);
    }

    if (options.extra[noReplayKey] == true) return handler.next(err);

    try {
      options.extra[_retriedKey] = true;
      options.headers['Authorization'] = 'Bearer ${_tokens.accessToken}';
      handler.resolve(await _dio.fetch(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
