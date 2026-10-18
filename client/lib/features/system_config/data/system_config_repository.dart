import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/api_client.dart';
import 'models/system_config.dart';

/// Read access to library rules. Throws `ApiException` on failure.
abstract interface class SystemConfigRepository {
  Future<SystemConfig> fetch();
  Future<SystemConfig> update(Map<String, dynamic> patch);
}

class SystemConfigApi implements SystemConfigRepository {
  SystemConfigApi(this._dio);

  final Dio _dio;

  @override
  Future<SystemConfig> fetch() => apiCall(
        () => _dio.get<Map<String, dynamic>>('/api/v1/system-config'),
        SystemConfig.fromJson,
      );

  @override
  Future<SystemConfig> update(Map<String, dynamic> patch) => apiCall(
        () => _dio.patch<Map<String, dynamic>>('/api/v1/system-config', data: patch),
        SystemConfig.fromJson,
      );
}

final systemConfigRepositoryProvider =
    Provider<SystemConfigRepository>((ref) => SystemConfigApi(ref.read(dioProvider)));
