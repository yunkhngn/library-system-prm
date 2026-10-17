import 'package:client/core/network/paged.dart';
import 'package:client/core/storage/token_storage.dart';
import 'package:client/features/access/application/occupancy_providers.dart';
import 'package:client/features/access/data/access_history_repository.dart';
import 'package:client/features/access/data/models/access_session.dart';
import 'package:client/features/access/data/models/occupant.dart';
import 'package:client/features/access/data/models/occupancy.dart';
import 'package:client/features/access/data/models/subject.dart';
import 'package:client/features/access/data/occupancy_repository.dart';
import 'package:client/features/librarian/occupants/presentation/occupants_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyTokens extends TokenStorage {
  @override
  Future<String?> readRefreshToken() async => null;
}

class _FakeOccupancy implements OccupancyRepository {
  _FakeOccupancy(this.people);
  List<Occupant> people;

  @override
  Future<Occupancy> snapshot() async => Occupancy(
        count: people.length,
        maxCapacity: 250,
        nearCapacity: false,
        capacityEnforcement: false,
        revision: 1,
        asOf: DateTime.utc(2026, 10, 17),
      );

  @override
  Future<Paged<Occupant>> listPeople({String q = '', SubjectKind? kind, int page = 0, int size = 20}) async {
    var items = people;
    if (kind != null) items = items.where((o) => o.subject.kind == kind).toList();
    if (q.isNotEmpty) {
      items = items
          .where((o) => o.subject.fullName.contains(q) || o.subject.code.toLowerCase().contains(q.toLowerCase()))
          .toList();
    }
    return Paged(items: items, page: 0, size: size, totalElements: items.length, totalPages: 1);
  }
}

class _FakeHistory implements AccessHistoryRepository {
  @override
  Future<AccessSession> getById(String sessionId) async => throw UnimplementedError();

  @override
  Future<Paged<AccessSession>> list(AccessHistoryFilter filter) async =>
      const Paged(items: [], page: 0, size: 20, totalElements: 0, totalPages: 0);
}

Occupant _occ(String name, String code, {SubjectKind kind = SubjectKind.user}) => Occupant(
      sessionId: 's-$code',
      subject: Subject(id: code, kind: kind, code: code, fullName: name),
      checkInTime: DateTime.utc(2026, 10, 17, 6, 0),
      duration: const Duration(minutes: 20),
      checkInMethod: AccessMethod.qr,
    );

Future<void> _pump(WidgetTester tester, List<Occupant> people) async {
  tester.view.physicalSize = const Size(1440, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(_EmptyTokens()),
        occupancyRepositoryProvider.overrideWithValue(_FakeOccupancy(people)),
        occupancyProvider.overrideWith(() => OccupancyController(connectRealtime: false)),
        accessHistoryRepositoryProvider.overrideWithValue(_FakeHistory()),
      ],
      child: const MaterialApp(home: Scaffold(body: OccupantsScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final people = [
    _occ('Trần Minh Quân', 'SV001'),
    _occ('Ngô Thanh Hà', 'GUEST-000014', kind: SubjectKind.visitor),
  ];

  testWidgets('lists occupants with checkout action and no email column', (tester) async {
    await _pump(tester, people);

    expect(find.text('Trần Minh Quân'), findsOneWidget);
    expect(find.text('SV001'), findsOneWidget);
    expect(find.text('GUEST-000014'), findsOneWidget);
    expect(find.text('Ghi nhận ra'), findsNWidgets(2));
    expect(find.text('Email'), findsNothing);
  });

  testWidgets('empty library and no-result states', (tester) async {
    await _pump(tester, const []);
    expect(find.text('Hiện không có ai trong thư viện'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Không có kết quả'), findsOneWidget);
  });
}
