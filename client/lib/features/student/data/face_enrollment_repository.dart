import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/auth_interceptor.dart';

class FacePolicy {
  const FacePolicy(
      {required this.version,
      required this.title,
      required this.content,
      required this.minImages,
      required this.maxImages,
      required this.maxImageBytes,
      required this.maxTotalBytes,
      required this.maxPixels});
  factory FacePolicy.fromJson(Map<String, dynamic> json) {
    final rules = json['captureRules'] as Map<String, dynamic>;
    return FacePolicy(
        version: json['version'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        minImages: (rules['minImages'] as num).toInt(),
        maxImages: (rules['maxImages'] as num).toInt(),
        maxImageBytes: (rules['maxImageBytes'] as num).toInt(),
        maxTotalBytes: (rules['maxTotalImageBytes'] as num).toInt(),
        maxPixels: (rules['maxImagePixels'] as num).toInt());
  }
  final String version, title, content;
  final int minImages, maxImages, maxImageBytes, maxTotalBytes, maxPixels;
}

class FaceEnrollment {
  const FaceEnrollment(
      {required this.isEnrolled,
      required this.version,
      required this.imageCount,
      this.enrolledAt});
  factory FaceEnrollment.fromJson(Map<String, dynamic> json) => FaceEnrollment(
      isEnrolled: json['isEnrolled'] as bool,
      version: (json['version'] as num).toInt(),
      enrolledAt: DateTime.tryParse(json['enrolledAt'] as String? ?? ''),
      imageCount: (json['imageCount'] as num).toInt());
  final bool isEnrolled;
  final int version, imageCount;
  final DateTime? enrolledAt;
}

class FacePhoto {
  const FacePhoto({required this.bytes, required this.mimeType});
  final Uint8List bytes;
  final String mimeType;
}

abstract interface class FaceEnrollmentRepository {
  Future<FacePolicy> policy();
  Future<FaceEnrollment> status();
  Future<void> consent(String policyVersion);
  Future<FaceEnrollment> enroll(List<FacePhoto> photos, int version);
}

class FaceEnrollmentApi implements FaceEnrollmentRepository {
  FaceEnrollmentApi(this._dio);
  final Dio _dio;
  @override
  Future<FacePolicy> policy() => apiCall(
      () => _dio.get<Map<String, dynamic>>('/api/v1/face-policy'),
      FacePolicy.fromJson);
  @override
  Future<FaceEnrollment> status() => apiCall(
      () => _dio.get<Map<String, dynamic>>('/api/v1/me/face-enrollment'),
      FaceEnrollment.fromJson);
  @override
  Future<void> consent(String policyVersion) => apiCall(
      () => _dio.post<Map<String, dynamic>>('/api/v1/me/face-consent',
          data: {'policyVersion': policyVersion, 'accepted': true},
          options: Options(extra: {AuthInterceptor.noReplayKey: true})),
      (_) {});
  @override
  Future<FaceEnrollment> enroll(List<FacePhoto> photos, int version) {
    final form = FormData()..fields.add(MapEntry('version', '$version'));
    for (var i = 0; i < photos.length; i++) {
      final photo = photos[i];
      form.files.add(MapEntry(
          'images',
          MultipartFile.fromBytes(photo.bytes,
              filename:
                  'capture-${i + 1}.${photo.mimeType == 'image/png' ? 'png' : 'jpg'}',
              contentType: DioMediaType.parse(photo.mimeType))));
    }
    return apiCall(
        () => _dio.post<Map<String, dynamic>>('/api/v1/me/face-enrollment',
            data: form,
            options: Options(
                extra: {AuthInterceptor.noReplayKey: true},
                receiveTimeout: const Duration(seconds: 60))),
        FaceEnrollment.fromJson);
  }
}

final faceEnrollmentRepositoryProvider = Provider<FaceEnrollmentRepository>(
    (ref) => FaceEnrollmentApi(ref.read(dioProvider)));
