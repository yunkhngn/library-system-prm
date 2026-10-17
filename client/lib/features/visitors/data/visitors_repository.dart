import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paged.dart';
import 'models/visitor.dart';

abstract interface class VisitorsRepository {
  Future<Paged<Visitor>> list({String q = '', int page = 0, int size = 20});
  Future<Visitor> getById(String id);
  Future<Visitor> create({required String fullName});
}

class VisitorsApi implements VisitorsRepository {
  VisitorsApi(this._dio);
  final Dio _dio;

  @override
  Future<Paged<Visitor>> list({String q = '', int page = 0, int size = 20}) => apiCall(
        () => _dio.get<Map<String, dynamic>>(
          '/api/v1/visitors',
          queryParameters: {
            'page': page,
            'size': size,
            'sort': 'createdAt,desc',
            if (q.isNotEmpty) 'q': q,
          },
        ),
        (json) => Paged.fromJson(json, Visitor.fromJson),
      );

  @override
  Future<Visitor> getById(String id) => apiCall(
        () => _dio.get<Map<String, dynamic>>('/api/v1/visitors/$id'),
        Visitor.fromJson,
      );

  @override
  Future<Visitor> create({required String fullName}) => apiCall(
        () => _dio.post<Map<String, dynamic>>(
          '/api/v1/visitors',
          data: {'fullName': fullName},
        ),
        Visitor.fromJson,
      );
}

final visitorsRepositoryProvider =
    Provider<VisitorsRepository>((ref) => VisitorsApi(ref.read(dioProvider)));
