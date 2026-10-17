import 'package:client/core/network/api_error.dart';
import 'package:client/core/network/paged.dart';
import 'package:client/core/storage/token_storage.dart';
import 'package:client/features/access/data/manual_access_repository.dart';
import 'package:client/features/access/data/models/access_result.dart';
import 'package:client/features/access/data/models/occupant.dart';
import 'package:client/features/access/data/models/occupancy.dart';
import 'package:client/features/access/data/models/student_lookup.dart';
import 'package:client/features/access/data/models/subject.dart';
import 'package:client/features/access/data/occupancy_repository.dart';
import 'package:client/features/librarian/manual_access/presentation/manual_access_screen.dart';
import 'package:client/features/visitors/data/models/visitor.dart';
import 'package:client/features/visitors/data/visitors_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyTokens extends TokenStorage {
  @override
  Future<String?> readRefreshToken() async => null;
}

class _FakeManual implements ManualAccessRepository {
  _FakeManual({this.lookup, this.submitError, this.uncertain = false});

  StudentLookup? lookup;
  ApiException? submitError;
  bool uncertain;
  String? lastKey;
  int submits = 0;
  int polls = 0;

  @override
  Future<StudentLookup> lookupStudent(String code) async {
    if (lookup == null) throw const ApiException(code: 'RESOURCE_NOT_FOUND');
    return lookup!;
  }

  @override
  Future<AccessResult> recordManual({
    required String idempotencyKey,
    String? userId,
    String? visitorId,
    required AccessAction action,
    required String reason,
  }) async {
    submits++;
    lastKey = idempotencyKey;
    if (uncertain) throw const ApiException(code: ClientErrorCode.timeout);
    if (submitError != null) throw submitError!;
    return AccessResult(
      requestId: idempotencyKey,
      sessionId: 'sess',
      action: action,
      subject: Subject(id: userId ?? visitorId ?? 'x', kind: SubjectKind.user, code: 'SV002', fullName: 'Trần Minh Quân'),
      method: AccessMethod.manual,
      occurredAt: DateTime.utc(2026, 10, 17, 7, 25),
    );
  }

  @override
  Future<AccessRequestStatus> requestStatus(String idempotencyKey) async {
    polls++;
    expect(idempotencyKey, lastKey);
    return AccessRequestStatus(
      status: AccessRequestState.completed,
      httpStatus: 200,
      result: AccessResult(
        requestId: idempotencyKey,
        sessionId: 'sess',
        action: AccessAction.checkIn,
        subject: const Subject(id: 'u2', kind: SubjectKind.user, code: 'SV002', fullName: 'Trần Minh Quân'),
        method: AccessMethod.manual,
        occurredAt: DateTime.utc(2026, 10, 17, 7, 25),
      ),
      errorCode: null,
    );
  }
}

class _FakeOccupancy implements OccupancyRepository {
  @override
  Future<Occupancy> snapshot() async => Occupancy(
        count: 1,
        maxCapacity: 250,
        nearCapacity: false,
        capacityEnforcement: false,
        revision: 1,
        asOf: DateTime.utc(2026, 10, 17),
      );

  @override
  Future<Paged<Occupant>> listPeople({String q = '', SubjectKind? kind, int page = 0, int size = 20}) async =>
      const Paged(items: [], page: 0, size: 8, totalElements: 0, totalPages: 0);
}

class _FakeVisitors implements VisitorsRepository {
  @override
  Future<Visitor> create({required String fullName}) async => throw UnimplementedError();

  @override
  Future<Visitor> getById(String id) async => throw UnimplementedError();

  @override
  Future<Paged<Visitor>> list({String q = '', int page = 0, int size = 20}) async =>
      const Paged(items: [], page: 0, size: 8, totalElements: 0, totalPages: 0);
}

Future<void> _pump(WidgetTester tester, _FakeManual manual, {ManualAccessScreen? screen}) async {
  tester.view.physicalSize = const Size(1440, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(_EmptyTokens()),
        manualAccessRepositoryProvider.overrideWithValue(manual),
        occupancyRepositoryProvider.overrideWithValue(_FakeOccupancy()),
        visitorsRepositoryProvider.overrideWithValue(_FakeVisitors()),
      ],
      child: MaterialApp(home: Scaffold(body: screen ?? const ManualAccessScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

const _student = StudentLookup(
  id: 'u2',
  code: 'SV002',
  fullName: 'Trần Minh Quân',
  status: 'ACTIVE',
  isInside: false,
);

Future<void> _completeHappyPath(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, 'SV002');
  await tester.tap(find.text('Tìm sinh viên'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Tiếp theo'));
  await tester.tap(find.text('Tiếp theo'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ghi nhận vào'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Tiếp theo'));
  await tester.tap(find.text('Tiếp theo'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, 'Sinh viên quên điện thoại');
  await tester.pump();
  await tester.ensureVisible(find.text('Tiếp theo'));
  await tester.tap(find.text('Tiếp theo'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Xác nhận ghi nhận'));
  await tester.tap(find.text('Xác nhận ghi nhận'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('happy path records a check-in', (tester) async {
    final manual = _FakeManual(lookup: _student);
    await _pump(tester, manual);
    await _completeHappyPath(tester);

    expect(find.textContaining('Đã ghi nhận vào cho Trần Minh Quân'), findsOneWidget);
    expect(find.text('Ghi nhận lượt khác'), findsOneWidget);
    expect(manual.submits, 1);
    expect(manual.lastKey, isNotEmpty);
  });

  testWidgets('already-inside error stays on confirm without a new key after retry', (tester) async {
    final manual = _FakeManual(lookup: _student, submitError: const ApiException(code: 'ALREADY_INSIDE'));
    await _pump(tester, manual);
    await _completeHappyPath(tester);

    expect(find.text('Người này đang ở trong thư viện.'), findsOneWidget);
    expect(find.text('Xác nhận ghi nhận'), findsOneWidget);
    expect(manual.submits, 1);
  });

  testWidgets('uncertain outcome polls the same idempotency key', (tester) async {
    final manual = _FakeManual(lookup: _student, uncertain: true);
    await _pump(tester, manual);
    await _completeHappyPath(tester);

    expect(find.text('Chưa xác định được kết quả'), findsOneWidget);
    expect(find.text('Kiểm tra lại'), findsOneWidget);
    final key = manual.lastKey;
    await tester.tap(find.text('Kiểm tra lại'));
    await tester.pumpAndSettle();
    expect(manual.polls, 1);
    expect(manual.lastKey, key);
    expect(find.textContaining('Đã ghi nhận vào cho Trần Minh Quân'), findsOneWidget);
  });
}
