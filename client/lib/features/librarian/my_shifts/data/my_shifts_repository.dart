import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_call.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/paged.dart';
import 'models/shift.dart';

/// The signed-in librarian's schedule. Throws `ApiException` on failure.
abstract interface class MyShiftsRepository {
  /// Every shift assigned to me that overlaps [from, to), oldest first.
  Future<List<MyShift>> listMyShifts({required DateTime from, required DateTime to});

  /// Everyone assigned to [shiftId]; only allowed for shifts I am assigned to.
  Future<List<ShiftAssignment>> listAssignments(String shiftId);
}

class MyShiftsApi implements MyShiftsRepository {
  MyShiftsApi(this._dio);

  final Dio _dio;

  static const _pageSize = 100;
  static const _maxPages = 5;

  @override
  Future<List<MyShift>> listMyShifts({required DateTime from, required DateTime to}) =>
      _collect(
        (page) => _dio.get<Map<String, dynamic>>(
          '/api/v1/me/shifts',
          queryParameters: {
            'from': from.toUtc().toIso8601String(),
            'to': to.toUtc().toIso8601String(),
            'page': page,
            'size': _pageSize,
            'sort': 'startsAt,asc',
          },
        ),
        MyShift.fromJson,
      );

  @override
  Future<List<ShiftAssignment>> listAssignments(String shiftId) => _collect(
        (page) => _dio.get<Map<String, dynamic>>(
          '/api/v1/shifts/$shiftId/assignments',
          queryParameters: {'page': page, 'size': _pageSize},
        ),
        ShiftAssignment.fromJson,
      );

  /// A week view needs the whole range, not one page; [_maxPages] caps runaway loops.
  Future<List<T>> _collect<T>(
    Future<Response<Map<String, dynamic>>> Function(int page) request,
    T Function(Map<String, dynamic>) fromItem,
  ) async {
    final items = <T>[];
    for (var page = 0; page < _maxPages; page++) {
      final result = await apiCall(
        () => request(page),
        (json) => Paged.fromJson(json, fromItem),
      );
      items.addAll(result.items);
      if (!result.hasNext) break;
    }
    return items;
  }
}

final myShiftsRepositoryProvider =
    Provider<MyShiftsRepository>((ref) => MyShiftsApi(ref.read(dioProvider)));
