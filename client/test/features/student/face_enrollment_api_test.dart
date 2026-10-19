import 'dart:typed_data';

import 'package:client/core/network/auth_interceptor.dart';
import 'package:client/features/student/data/face_enrollment_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'consent sends explicit policy version and uploads repeat images with optimistic version',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
    addTearDown(dio.close);
    var calls = 0;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      calls++;
      expect(request.method, 'POST');
      expect(request.extra[AuthInterceptor.noReplayKey], true);
      if (request.path.endsWith('face-consent')) {
        expect(request.data, {'policyVersion': 'policy-2', 'accepted': true});
        handler.resolve(Response(
            requestOptions: request,
            statusCode: 200,
            data: <String, dynamic>{}));
      } else {
        expect(request.path, '/api/v1/me/face-enrollment');
        final form = request.data as FormData;
        expect(form.fields.single.key, 'version');
        expect(form.fields.single.value, '7');
        expect(form.files.map((entry) => entry.key),
            ['images', 'images', 'images']);
        expect(form.files.first.value.contentType.toString(), 'image/png');
        expect(form.files.first.value.filename, 'capture-1.png');
        handler.resolve(Response(
            requestOptions: request,
            statusCode: 200,
            data: {'isEnrolled': true, 'version': 8, 'imageCount': 3}));
      }
    }));
    final api = FaceEnrollmentApi(dio);
    await api.consent('policy-2');
    final result = await api.enroll(
        List.generate(
            3,
            (_) => FacePhoto(
                bytes: Uint8List.fromList([137, 80, 78, 71]),
                mimeType: 'image/png')),
        7);
    expect(result.isEnrolled, true);
    expect(result.version, 8);
    expect(calls, 2);
  });
}
