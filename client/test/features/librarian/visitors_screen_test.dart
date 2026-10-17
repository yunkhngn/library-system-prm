import 'package:client/core/network/paged.dart';
import 'package:client/features/librarian/visitors/presentation/visitor_detail_screen.dart';
import 'package:client/features/librarian/visitors/presentation/visitors_screen.dart';
import 'package:client/features/visitors/data/models/visitor.dart';
import 'package:client/features/visitors/data/visitors_repository.dart';
import 'package:client/core/storage/token_storage.dart';
import 'package:client/features/access/application/occupancy_providers.dart';
import 'package:client/features/access/data/access_history_repository.dart';
import 'package:client/features/access/data/models/access_session.dart';
import 'package:client/features/access/data/models/occupant.dart';
import 'package:client/features/access/data/models/occupancy.dart';
import 'package:client/features/access/data/models/subject.dart';
import 'package:client/features/access/data/occupancy_repository.dart';
import 'package:client/shared/models/actor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyTokens extends TokenStorage {
  @override
  Future<String?> readRefreshToken() async => null;
}

class _FakeVisitors implements VisitorsRepository {
  _FakeVisitors(this.items);
  final List<Visitor> items;

  @override
  Future<Visitor> create({required String fullName}) async => Visitor(
        id: 'new',
        referenceCode: 'GUEST-000099',
        fullName: fullName,
        createdBy: const Actor(id: 'lib', code: 'LIB001', fullName: 'Lê Thu Trang'),
        createdAt: DateTime.utc(2026, 10, 17, 3, 2),
      );

  @override
  Future<Visitor> getById(String id) async => items.firstWhere((v) => v.id == id);

  @override
  Future<Paged<Visitor>> list({String q = '', int page = 0, int size = 20}) async {
    final filtered = q.isEmpty
        ? items
        : items.where((v) => v.fullName.contains(q) || v.referenceCode.contains(q)).toList();
    return Paged(items: filtered, page: 0, size: size, totalElements: filtered.length, totalPages: 1);
  }
}

class _FakeOccupancy implements OccupancyRepository {
  @override
  Future<Occupancy> snapshot() async => Occupancy(
        count: 0,
        maxCapacity: 250,
        nearCapacity: false,
        capacityEnforcement: false,
        revision: 1,
        asOf: DateTime.utc(2026, 10, 17),
      );

  @override
  Future<Paged<Occupant>> listPeople({String q = '', SubjectKind? kind, int page = 0, int size = 20}) async =>
      const Paged(items: [], page: 0, size: 20, totalElements: 0, totalPages: 0);
}

class _FakeHistory implements AccessHistoryRepository {
  @override
  Future<AccessSession> getById(String sessionId) async => throw UnimplementedError();

  @override
  Future<Paged<AccessSession>> list(AccessHistoryFilter filter) async =>
      const Paged(items: [], page: 0, size: 20, totalElements: 0, totalPages: 0);
}

Visitor _v(String id, String name, String code) => Visitor(
      id: id,
      referenceCode: code,
      fullName: name,
      createdBy: const Actor(id: 'lib', code: 'LIB001', fullName: 'Lê Thu Trang'),
      createdAt: DateTime.utc(2026, 10, 17, 3, 2),
    );

List<Override> _overrides(List<Visitor> items) => [
      visitorsRepositoryProvider.overrideWithValue(_FakeVisitors(items)),
      occupancyRepositoryProvider.overrideWithValue(_FakeOccupancy()),
      occupancyProvider.overrideWith(() => OccupancyController(connectRealtime: false)),
      accessHistoryRepositoryProvider.overrideWithValue(_FakeHistory()),
      tokenStorageProvider.overrideWithValue(_EmptyTokens()),
    ];

void main() {
  final guests = [
    _v('1', 'Vũ Đức Anh', 'GUEST-000012'),
    _v('2', 'Vũ Đức Anh', 'GUEST-000013'),
  ];

  testWidgets('lists visitors distinguished by code and creates one', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(guests),
        child: const MaterialApp(home: Scaffold(body: VisitorsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GUEST-000012'), findsOneWidget);
    expect(find.text('GUEST-000013'), findsOneWidget);
    expect(find.text('Vũ Đức Anh'), findsNWidgets(2));
    expect(find.text('Sửa'), findsNothing);
    expect(find.text('Xóa'), findsNothing);

    await tester.tap(find.text('Thêm khách ngoài'));
    await tester.pumpAndSettle();
    expect(find.textContaining('không tự động ghi nhận'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Ngô Thanh Hà');
    await tester.tap(find.text('Thêm khách'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đã thêm Ngô Thanh Hà (GUEST-000099)'), findsOneWidget);
    expect(find.text('Ghi nhận vào'), findsOneWidget);
  });

  testWidgets('visitor detail is read-only and shows presence', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(guests),
        child: const MaterialApp(home: Scaffold(body: VisitorDetailScreen(visitorId: '1'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vũ Đức Anh'), findsWidgets);
    expect(find.text('GUEST-000012'), findsOneWidget);
    expect(find.text('Ngoài thư viện'), findsOneWidget);
    expect(find.text('Ghi nhận vào'), findsOneWidget);
    expect(find.text('Sửa'), findsNothing);
    expect(find.text('Xóa'), findsNothing);
  });
}
