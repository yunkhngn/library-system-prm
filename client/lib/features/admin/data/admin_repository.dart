import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paged.dart';
import 'admin_models.dart';

abstract interface class AdminRepository {
  Future<Paged<AdminAccount>> listAccounts(Map<String, dynamic> query);
  Future<AdminAccount> createAccount(Map<String, dynamic> body);
  Future<Paged<AdminKiosk>> listKiosks(Map<String, dynamic> query);
  Future<AdminKiosk> getKiosk(String id);
  Future<KioskCredential> createKiosk(Map<String, dynamic> body);
  Future<AdminKiosk> updateKiosk(String id, Map<String, dynamic> body);
  Future<KioskCredential> rotateKioskCredential(String id, int version);
  Future<Paged<AdminShift>> listShifts(Map<String, dynamic> query);
  Future<AdminShift> createShift(Map<String, dynamic> body);
  Future<AdminShift> cancelShift(String id, Map<String, dynamic> body);
  Future<AccessAnalytics> accessAnalytics(Map<String, dynamic> query);
  Future<RecognitionAnalytics> recognitionAnalytics(Map<String, dynamic> query);
}

class AdminApi implements AdminRepository {
  AdminApi(this._dio);
  final Dio _dio;

  @override
  Future<Paged<AdminAccount>> listAccounts(Map<String, dynamic> query) =>
      apiCall(
          () => _dio.get<Map<String, dynamic>>('/api/v1/users',
              queryParameters: query),
          (json) => Paged.fromJson(json, AdminAccount.fromJson));
  @override
  Future<AdminAccount> createAccount(Map<String, dynamic> body) => apiCall(
      () => _dio.post<Map<String, dynamic>>('/api/v1/users', data: body),
      AdminAccount.fromJson);
  @override
  Future<Paged<AdminKiosk>> listKiosks(Map<String, dynamic> query) => apiCall(
      () => _dio.get<Map<String, dynamic>>('/api/v1/kiosks',
          queryParameters: query),
      (json) => Paged.fromJson(json, AdminKiosk.fromJson));
  @override
  Future<AdminKiosk> getKiosk(String id) => apiCall(
      () => _dio.get<Map<String, dynamic>>('/api/v1/kiosks/$id'),
      AdminKiosk.fromJson);
  @override
  Future<KioskCredential> createKiosk(Map<String, dynamic> body) => apiCall(
      () => _dio.post<Map<String, dynamic>>('/api/v1/kiosks', data: body),
      KioskCredential.fromJson);
  @override
  Future<AdminKiosk> updateKiosk(String id, Map<String, dynamic> body) =>
      apiCall(
          () => _dio.patch<Map<String, dynamic>>('/api/v1/kiosks/$id',
              data: body),
          AdminKiosk.fromJson);
  @override
  Future<KioskCredential> rotateKioskCredential(String id, int version) =>
      apiCall(
          () => _dio.post<Map<String, dynamic>>(
              '/api/v1/kiosks/$id/rotate-credential',
              data: {'version': version}),
          KioskCredential.fromJson);
  @override
  Future<Paged<AdminShift>> listShifts(Map<String, dynamic> query) => apiCall(
      () => _dio.get<Map<String, dynamic>>('/api/v1/shifts',
          queryParameters: query),
      (json) => Paged.fromJson(json, AdminShift.fromJson));
  @override
  Future<AdminShift> createShift(Map<String, dynamic> body) => apiCall(
      () => _dio.post<Map<String, dynamic>>('/api/v1/shifts', data: body),
      AdminShift.fromJson);
  @override
  Future<AdminShift> cancelShift(String id, Map<String, dynamic> body) =>
      apiCall(
          () => _dio.post<Map<String, dynamic>>('/api/v1/shifts/$id/cancel',
              data: body),
          AdminShift.fromJson);
  @override
  Future<AccessAnalytics> accessAnalytics(Map<String, dynamic> query) =>
      apiCall(
          () => _dio.get<Map<String, dynamic>>('/api/v1/analytics/access',
              queryParameters: query),
          AccessAnalytics.fromJson);
  @override
  Future<RecognitionAnalytics> recognitionAnalytics(
          Map<String, dynamic> query) =>
      apiCall(
          () => _dio.get<Map<String, dynamic>>('/api/v1/analytics/recognition',
              queryParameters: query),
          RecognitionAnalytics.fromJson);
}

final adminRepositoryProvider =
    Provider<AdminRepository>((ref) => AdminApi(ref.read(dioProvider)));
