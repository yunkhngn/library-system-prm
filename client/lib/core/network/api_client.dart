import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/session_controller.dart';
import '../config/env.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      contentType: Headers.jsonContentType,
    ),
  );
  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      tokens: ref.read(tokenStorageProvider),
      refreshSession: () => ref.read(sessionControllerProvider.notifier).refresh(),
      onSessionExpired: () => ref.read(sessionControllerProvider.notifier).expire(),
    ),
  );
  return dio;
});

/// Options for endpoints that must not carry or refresh the access token
/// (login, refresh).
Options get publicRequest => Options(extra: {AuthInterceptor.skipAuthKey: true});
