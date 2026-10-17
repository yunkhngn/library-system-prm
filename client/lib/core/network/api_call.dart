import 'package:dio/dio.dart';

import 'api_error.dart';

/// Runs a JSON request and maps transport/server failures to [ApiException],
/// so repositories never leak [DioException] to the application layer.
Future<T> apiCall<T>(
  Future<Response<Map<String, dynamic>>> Function() request,
  T Function(Map<String, dynamic>) parse,
) async {
  try {
    final response = await request();
    return parse(response.data!);
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
}
