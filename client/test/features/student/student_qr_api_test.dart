import 'dart:typed_data';

import 'package:client/core/network/api_error.dart';
import 'package:client/core/network/auth_interceptor.dart';
import 'package:client/core/storage/token_storage.dart';
import 'package:client/features/student/data/student_qr_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  int calls = 0;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('QR creation uses the personal POST and parses the response', () async {
    final adapter = _Adapter((options) {
      expect(options.method, 'POST');
      expect(options.path, '/api/v1/me/qr');
      expect(options.extra[AuthInterceptor.noReplayKey], true);
      expect(options.queryParameters, isEmpty);
      return ResponseBody.fromString(
          '{"token":"signed-qr","expiresAt":"2026-10-19T03:00:30Z","refreshAfterSeconds":25}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          });
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'))
      ..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final result = await StudentQrApi(dio).issue();
    expect(result.token, 'signed-qr');
    expect(result.expiresAt, DateTime.utc(2026, 10, 19, 3, 0, 30));
    expect(result.refreshAfterSeconds, 25);
    expect(adapter.calls, 1);
  });

  test('429 honors Retry-After and never retries the POST', () async {
    final adapter =
        _Adapter((_) => ResponseBody.fromString('{}', 429, headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
              'retry-after': ['12']
            }));
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'))
      ..httpClientAdapter = adapter;
    addTearDown(dio.close);
    await expectLater(
        StudentQrApi(dio).issue(),
        throwsA(isA<QrRateLimited>()
            .having((e) => e.retryAfterSeconds, 'retry after', 12)));
    expect(adapter.calls, 1);
  });

  test('401 refreshes authentication without replaying QR issuance', () async {
    final adapter = _Adapter((_) =>
        ResponseBody.fromString('{"code":"TOKEN_EXPIRED"}', 401, headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        }));
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'))
      ..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final tokens = TokenStorage()..accessToken = 'old';
    var refreshes = 0;
    dio.interceptors.add(AuthInterceptor(
        dio: dio,
        tokens: tokens,
        refreshSession: () async {
          refreshes++;
          tokens.accessToken = 'new';
          return true;
        },
        onSessionExpired: () => fail('Session refreshed successfully')));
    await expectLater(StudentQrApi(dio).issue(), throwsA(isA<ApiException>()));
    expect(refreshes, 1);
    expect(adapter.calls, 1);
    expect(tokens.accessToken, 'new');
  });
}
