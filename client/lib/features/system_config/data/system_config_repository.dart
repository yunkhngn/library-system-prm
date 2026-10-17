import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/api_client.dart';
import 'models/system_config.dart';

/// Read access to library rules. Throws `ApiException` on failure.
abstract interface class SystemConfigRepository {
  Future<SystemConfig> fetch();
}

class SystemConfigApi implements SystemConfigRepository {
  SystemConfigApi(this._dio);

  final Dio _dio;

  @override
  Future<SystemConfig> fetch() => apiCall(
        () => _dio.get<Map<String, dynamic>>('/api/v1/system-config'),
        SystemConfig.fromJson,
      );
}

final systemConfigRepositoryProvider =
    Provider<SystemConfigRepository>((ref) => SystemConfigApi(ref.read(dioProvider)));
