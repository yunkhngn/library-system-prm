import 'package:client/core/network/paged.dart';
import 'package:client/features/access/data/access_history_repository.dart';
import 'package:client/features/access/data/models/access_session.dart';
import 'package:client/features/access/data/models/subject.dart';
import 'package:client/features/librarian/access_history/presentation/access_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeHistory implements AccessHistoryRepository {
  _FakeHistory(this.sessions);
  final List<AccessSession> sessions;
  AccessHistoryFilter? last;

  @override
  Future<Paged<AccessSession>> list(AccessHistoryFilter filter) async {
    last = filter;
    var items = sessions;
    if (filter.q.isNotEmpty) {
      items = items
          .where((s) => s.subject.fullName.contains(filter.q) || s.subject.code.contains(filter.q))
          .toList();
    }
    if (filter.isOpen != null) {
      items = items.where((s) => s.isOpen == filter.isOpen).toList();
    }
    if (filter.method != null) {
      items = items.where((s) => s.checkInMethod == filter.method || s.checkOutMethod == filter.method).toList();
    }
    return Paged(items: items, page: 0, size: 20, totalElements: items.length, totalPages: 1);
  }

  @override
  Future<AccessSession> getById(String sessionId) async => sessions.firstWhere((s) => s.id == sessionId);
}

AccessSession _session({
  required String name,
  required String code,
  SubjectKind kind = SubjectKind.user,
  bool open = false,
}) =>
    AccessSession(
      id: code,
      subject: Subject(id: code, kind: kind, code: code, fullName: name),
      checkInTime: DateTime.utc(2026, 10, 17, 6, 0),
      checkOutTime: open ? null : DateTime.utc(2026, 10, 17, 8, 0),
      checkInMethod: AccessMethod.face,
      checkOutMethod: open ? null : AccessMethod.manual,
      checkInKiosk: const KioskSummary(id: 'k1', code: 'KIOSK-01', name: 'Cổng chính'),
      checkOutKiosk: null,
      checkInBy: null,
      checkOutBy: null,
      checkoutReason: open ? null : 'USER_ACTION',
      manualReason: null,
      checkOutManualReason: null,
      duration: const Duration(hours: 2),
    );

Future<void> _pump(WidgetTester tester, _FakeHistory repo) async {
  tester.view.physicalSize = const Size(1440, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [accessHistoryRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: Scaffold(body: AccessHistoryScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists today sessions and opens the detail drawer', (tester) async {
    final repo = _FakeHistory([
      _session(name: 'Trần Minh Quân', code: 'SV001', open: true),
      _session(name: 'Ngô Thanh Hà', code: 'GUEST-000014', kind: SubjectKind.visitor),
    ]);
    await _pump(tester, repo);

    expect(repo.last?.q, '');
    expect(find.text('Trần Minh Quân'), findsOneWidget);
    expect(find.text('GUEST-000014'), findsOneWidget);
    expect(find.text('Xuất'), findsNothing);

    await tester.tap(find.text('Trần Minh Quân'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết lượt ra vào'), findsOneWidget);
    expect(find.text('Cổng chính'), findsOneWidget);
  });

  testWidgets('empty today state', (tester) async {
    await _pump(tester, _FakeHistory(const []));
    expect(find.text('Chưa có lượt ra vào hôm nay'), findsOneWidget);
  });
}
