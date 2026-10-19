import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paged.dart';
import '../../access/data/models/access_session.dart';

abstract interface class StudentHistoryRepository {
  Future<Paged<AccessSession>> list(
      {required DateTime from, required DateTime to, int page = 0});
  Future<AccessSession> detail(String sessionId);
}

class StudentHistoryApi implements StudentHistoryRepository {
  StudentHistoryApi(this._dio);
  final Dio _dio;

  @override
  Future<Paged<AccessSession>> list(
          {required DateTime from, required DateTime to, int page = 0}) =>
      apiCall(
        () => _dio.get<Map<String, dynamic>>('/api/v1/me/access-history',
            queryParameters: {
              'from': from.toUtc().toIso8601String(),
              'to': to.toUtc().toIso8601String(),
              'page': page,
              'size': 20,
              'sort': 'checkInTime,desc',
            }),
        (json) => Paged.fromJson(json, AccessSession.fromJson),
      );

  @override
  Future<AccessSession> detail(String sessionId) => apiCall(
        () => _dio.get<Map<String, dynamic>>(
            '/api/v1/me/access-history/${Uri.encodeComponent(sessionId)}'),
        AccessSession.fromJson,
      );
}

final studentHistoryRepositoryProvider = Provider<StudentHistoryRepository>(
    (ref) => StudentHistoryApi(ref.read(dioProvider)));
