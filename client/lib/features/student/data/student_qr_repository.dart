import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/auth_interceptor.dart';

class StudentQrToken {
  const StudentQrToken(
      {required this.token,
      required this.expiresAt,
      required this.refreshAfterSeconds});

  factory StudentQrToken.fromJson(Map<String, dynamic> json) {
    final token = json['token'] as String;
    if (token.isEmpty) throw const FormatException('Empty QR token');
    return StudentQrToken(
      token: token,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      refreshAfterSeconds: (json['refreshAfterSeconds'] as num).toInt(),
    );
  }

  final String token;
  final DateTime expiresAt;
  final int refreshAfterSeconds;
}

class QrRateLimited extends ApiException {
  const QrRateLimited(this.retryAfterSeconds)
      : super(code: 'RATE_LIMITED', statusCode: 429);
  final int retryAfterSeconds;
}

abstract interface class StudentQrRepository {
  Future<StudentQrToken> issue();
}

class StudentQrApi implements StudentQrRepository {
  StudentQrApi(this._dio);
  final Dio _dio;

  @override
  Future<StudentQrToken> issue() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('/api/v1/me/qr',
          options: Options(extra: {AuthInterceptor.noReplayKey: true}));
      return StudentQrToken.fromJson(response.data!);
    } on DioException catch (error) {
      if (error.response?.statusCode == 429) {
        final retry =
            int.tryParse(error.response?.headers.value('retry-after') ?? '') ??
                30;
        throw QrRateLimited(retry > 0 ? retry : 1);
      }
      throw ApiException.fromDio(error);
    }
  }
}

final studentQrRepositoryProvider =
    Provider<StudentQrRepository>((ref) => StudentQrApi(ref.read(dioProvider)));
