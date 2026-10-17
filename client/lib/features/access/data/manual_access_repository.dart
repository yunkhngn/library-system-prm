import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/api_client.dart';
import 'models/access_result.dart';
import 'models/student_lookup.dart';
import 'models/subject.dart';

abstract interface class ManualAccessRepository {
  Future<StudentLookup> lookupStudent(String code);
  Future<AccessResult> recordManual({
    required String idempotencyKey,
    String? userId,
    String? visitorId,
    required AccessAction action,
    required String reason,
  });
  Future<AccessRequestStatus> requestStatus(String idempotencyKey);
}

class ManualAccessApi implements ManualAccessRepository {
  ManualAccessApi(this._dio);
  final Dio _dio;

  @override
  Future<StudentLookup> lookupStudent(String code) => apiCall(
        () => _dio.get<Map<String, dynamic>>(
          '/api/v1/students/lookup',
          queryParameters: {'code': code},
        ),
        StudentLookup.fromJson,
      );

  @override
  Future<AccessResult> recordManual({
    required String idempotencyKey,
    String? userId,
    String? visitorId,
    required AccessAction action,
    required String reason,
  }) =>
      apiCall(
        () => _dio.post<Map<String, dynamic>>(
          '/api/v1/access/manual',
          data: {
            if (userId != null) 'userId': userId,
            if (visitorId != null) 'visitorId': visitorId,
            'action': action.apiValue,
            'reason': reason,
          },
          options: Options(headers: {'Idempotency-Key': idempotencyKey}),
        ),
        AccessResult.fromJson,
      );

  @override
  Future<AccessRequestStatus> requestStatus(String idempotencyKey) => apiCall(
        () => _dio.get<Map<String, dynamic>>('/api/v1/access/requests/$idempotencyKey'),
        AccessRequestStatus.fromJson,
      );
}

final manualAccessRepositoryProvider =
    Provider<ManualAccessRepository>((ref) => ManualAccessApi(ref.read(dioProvider)));
