import 'dart:typed_data';

import 'package:client/core/network/api_error.dart';
import 'package:client/features/student/data/student_history_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      respond(options);
  @override
  void close({bool force = false}) {}
}

void main() {
  test(
      'student history uses only personal API, UTC range and supported paging/sort',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'))
      ..httpClientAdapter = _Adapter((options) {
        expect(options.method, 'GET');
        expect(options.path, '/api/v1/me/access-history');
        expect(options.queryParameters, {
          'from': '2026-09-30T17:00:00.000Z',
          'to': '2026-10-13T17:00:00.000Z',
          'page': 2,
          'size': 20,
          'sort': 'checkInTime,desc',
        });
        return ResponseBody.fromString(
            '{"items":[],"page":2,"size":20,"totalElements":40,"totalPages":2}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType]
            });
      });
    addTearDown(dio.close);
    final page = await StudentHistoryApi(dio).list(
        from: DateTime.parse('2026-10-01T00:00:00+07:00'),
        to: DateTime.parse('2026-10-14T00:00:00+07:00'),
        page: 2);
    expect(page.page, 2);
    expect(page.items, isEmpty);
  });

  test(
      'detail encodes the ID, never sends userId and normalizes missing-resource errors',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'))
      ..httpClientAdapter = _Adapter((options) {
        expect(options.method, 'GET');
        expect(options.path, '/api/v1/me/access-history/session%2Fother');
        expect(options.queryParameters, isEmpty);
        return ResponseBody.fromString('{"code":"RESOURCE_NOT_FOUND"}', 404,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType]
            });
      });
    addTearDown(dio.close);
    await expectLater(
        StudentHistoryApi(dio).detail('session/other'),
        throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 404)));
  });
}
