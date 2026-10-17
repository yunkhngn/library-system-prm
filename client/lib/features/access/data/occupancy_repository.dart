import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paged.dart';
import 'models/occupant.dart';
import 'models/occupancy.dart';
import 'models/subject.dart';

abstract interface class OccupancyRepository {
  Future<Occupancy> snapshot();
  Future<Paged<Occupant>> listPeople({String q = '', SubjectKind? kind, int page = 0, int size = 20});
}

class OccupancyApi implements OccupancyRepository {
  OccupancyApi(this._dio);
  final Dio _dio;

  @override
  Future<Occupancy> snapshot() => apiCall(
        () => _dio.get<Map<String, dynamic>>('/api/v1/occupancy'),
        Occupancy.fromJson,
      );

  @override
  Future<Paged<Occupant>> listPeople({
    String q = '',
    SubjectKind? kind,
    int page = 0,
    int size = 20,
  }) =>
      apiCall(
        () => _dio.get<Map<String, dynamic>>(
          '/api/v1/occupancy/people',
          queryParameters: {
            'page': page,
            'size': size,
            if (q.isNotEmpty) 'q': q,
            if (kind != null) 'kind': kind.apiValue,
          },
        ),
        (json) => Paged.fromJson(json, Occupant.fromJson),
      );
}

final occupancyRepositoryProvider =
    Provider<OccupancyRepository>((ref) => OccupancyApi(ref.read(dioProvider)));
