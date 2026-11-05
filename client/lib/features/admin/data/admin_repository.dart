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
  Future<AdminShift> getShift(String id);
  Future<List<AdminAssignment>> listActiveAssignments(String shiftId);
  Future<void> assignStaff(String shiftId, int version, List<String> staffIds);
  Future<void> replaceAssignedStaff(
      String shiftId, String assignmentId, int version, String staffId);
  Future<void> cancelAssignment(
      String shiftId, String assignmentId, int version);
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
  Future<AdminShift> getShift(String id) => apiCall(
      () => _dio.get<Map<String, dynamic>>('/api/v1/shifts/$id'),
      AdminShift.fromJson);
  @override
  Future<List<AdminAssignment>> listActiveAssignments(String shiftId) =>
      apiCall(
          () => _dio.get<Map<String, dynamic>>(
              '/api/v1/shifts/$shiftId/assignments',
              queryParameters: {'status': 'ACTIVE', 'page': 0, 'size': 100}),
          (json) => Paged.fromJson(json, AdminAssignment.fromJson).items);
  @override
  Future<void> assignStaff(
          String shiftId, int version, List<String> staffIds) =>
      apiCallVoid(() => _dio.post<dynamic>(
          '/api/v1/shifts/$shiftId/assignments',
          data: {'version': version, 'staffIds': staffIds}));
  @override
  Future<void> replaceAssignedStaff(
          String shiftId, String assignmentId, int version, String staffId) =>
      apiCallVoid(() => _dio.patch<dynamic>(
          '/api/v1/shifts/$shiftId/assignments/$assignmentId',
          data: {'version': version, 'staffId': staffId}));
  @override
  Future<void> cancelAssignment(
          String shiftId, String assignmentId, int version) =>
      apiCallVoid(() => _dio.delete<dynamic>(
          '/api/v1/shifts/$shiftId/assignments/$assignmentId',
          queryParameters: {'version': version}));
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
