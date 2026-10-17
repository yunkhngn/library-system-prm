import 'package:dio/dio.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import 'auth_repository.dart';
import 'models/token_pair.dart';
import 'models/user.dart';

/// [AuthRepository] backed by the REST API.
class AuthApi implements AuthRepository {
  AuthApi(this._dio);

  final Dio _dio;

  @override
  Future<TokenPair> login({required String identifier, required String password}) => _call(
        () => _dio.post<Map<String, dynamic>>(
          '/api/v1/auth/login',
          data: {'identifier': identifier.trim(), 'password': password},
          options: publicRequest,
        ),
        TokenPair.fromJson,
      );

  @override
  Future<TokenPair> refresh(String refreshToken) => _call(
        () => _dio.post<Map<String, dynamic>>(
          '/api/v1/auth/refresh',
          data: {'refreshToken': refreshToken},
          options: publicRequest,
        ),
        TokenPair.fromJson,
      );

  @override
  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post<void>('/api/v1/auth/logout', data: {'refreshToken': refreshToken});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<User> me() => _call(
        () => _dio.get<Map<String, dynamic>>('/api/v1/me'),
        User.fromJson,
      );

  /// Passwords are sent as typed; never trim them.
  @override
  Future<TokenPair> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _call(
        () => _dio.put<Map<String, dynamic>>(
          '/api/v1/me/password',
          data: {'currentPassword': currentPassword, 'newPassword': newPassword},
        ),
        TokenPair.fromJson,
      );

  Future<T> _call<T>(
    Future<Response<Map<String, dynamic>>> Function() request,
    T Function(Map<String, dynamic>) parse,
  ) =>
      apiCall(request, parse);
}
