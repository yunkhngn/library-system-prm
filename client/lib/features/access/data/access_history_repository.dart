import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paged.dart';
import 'models/access_session.dart';
import 'models/subject.dart';

class AccessHistoryFilter {
  const AccessHistoryFilter({
    this.from,
    this.to,
    this.q = '',
    this.userId,
    this.visitorId,
    this.isOpen,
    this.method,
    this.page = 0,
    this.size = 20,
  });

  final DateTime? from;
  final DateTime? to;
  final String q;
  final String? userId;
  final String? visitorId;
  final bool? isOpen;
  final AccessMethod? method;
  final int page;
  final int size;
}

abstract interface class AccessHistoryRepository {
  Future<Paged<AccessSession>> list(AccessHistoryFilter filter);
  Future<AccessSession> getById(String sessionId);
}

class AccessHistoryApi implements AccessHistoryRepository {
  AccessHistoryApi(this._dio);
  final Dio _dio;

  @override
  Future<Paged<AccessSession>> list(AccessHistoryFilter filter) => apiCall(
        () => _dio.get<Map<String, dynamic>>(
          '/api/v1/access-history',
          queryParameters: {
            'page': filter.page,
            'size': filter.size,
            'sort': 'checkInTime,desc',
            if (filter.from != null) 'from': filter.from!.toUtc().toIso8601String(),
            if (filter.to != null) 'to': filter.to!.toUtc().toIso8601String(),
            if (filter.q.isNotEmpty) 'q': filter.q,
            if (filter.userId != null) 'userId': filter.userId,
            if (filter.visitorId != null) 'visitorId': filter.visitorId,
            if (filter.isOpen != null) 'isOpen': filter.isOpen,
            if (filter.method != null) 'method': filter.method!.apiValue,
          },
        ),
        (json) => Paged.fromJson(json, AccessSession.fromJson),
      );

  @override
  Future<AccessSession> getById(String sessionId) => apiCall(
        () => _dio.get<Map<String, dynamic>>('/api/v1/access-history/$sessionId'),
        AccessSession.fromJson,
      );
}

final accessHistoryRepositoryProvider =
    Provider<AccessHistoryRepository>((ref) => AccessHistoryApi(ref.read(dioProvider)));
