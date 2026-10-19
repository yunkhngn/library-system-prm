import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paged.dart';
import '../../access/data/models/access_session.dart';

class StudentAccessStatus {
  const StudentAccessStatus(
      {required this.isInside,
      required this.currentSession,
      required this.asOf});

  factory StudentAccessStatus.fromJson(Map<String, dynamic> json) =>
      StudentAccessStatus(
        isInside: json['isInside'] as bool,
        currentSession: json['currentSession'] == null
            ? null
            : AccessSession.fromJson(
                json['currentSession'] as Map<String, dynamic>),
        asOf: DateTime.parse(json['asOf'] as String),
      );

  final bool isInside;
  final AccessSession? currentSession;
  final DateTime asOf;
}

abstract interface class StudentHomeRepository {
  Future<StudentAccessStatus> accessStatus();
  Future<Paged<AccessSession>> recentHistory();
}

class StudentHomeApi implements StudentHomeRepository {
  StudentHomeApi(this._dio);
  final Dio _dio;

  @override
  Future<StudentAccessStatus> accessStatus() => apiCall(
        () => _dio.get<Map<String, dynamic>>('/api/v1/me/access-status'),
        StudentAccessStatus.fromJson,
      );

  @override
  Future<Paged<AccessSession>> recentHistory() => apiCall(
        () => _dio.get<Map<String, dynamic>>('/api/v1/me/access-history',
            queryParameters: {
              'page': 0,
              'size': 3,
              'sort': 'checkInTime,desc',
            }),
        (json) => Paged.fromJson(json, AccessSession.fromJson),
      );
}

final studentHomeRepositoryProvider = Provider<StudentHomeRepository>(
  (ref) => StudentHomeApi(ref.read(dioProvider)),
);
