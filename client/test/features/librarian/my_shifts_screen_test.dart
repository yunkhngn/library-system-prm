import 'package:client/core/storage/token_storage.dart';
import 'package:client/core/utils/formatters.dart';
import 'package:client/features/librarian/my_shifts/data/models/shift.dart';
import 'package:client/features/librarian/my_shifts/data/my_shifts_repository.dart';
import 'package:client/features/librarian/my_shifts/presentation/my_shifts_screen.dart';
import 'package:client/shared/models/actor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyTokenStorage extends TokenStorage {
  @override
  Future<String?> readRefreshToken() async => null;
}

class _FakeShiftsRepository implements MyShiftsRepository {
  _FakeShiftsRepository(this.shifts);

  final List<MyShift> shifts;
  final requestedRanges = <(DateTime, DateTime)>[];

  @override
  Future<List<MyShift>> listMyShifts({required DateTime from, required DateTime to}) async {
    requestedRanges.add((from, to));
    return shifts
        .where((s) => s.shift.startsAt.isBefore(to) && s.shift.endsAt.isAfter(from))
        .toList();
  }

  @override
  Future<List<ShiftAssignment>> listAssignments(String shiftId) async => const [
        ShiftAssignment(
          id: 'a1',
          staff: Actor(id: 'u1', code: 'LIB001', fullName: 'Lê Thu Trang'),
          status: ScheduleStatus.active,
        ),
        ShiftAssignment(
          id: 'a2',
          staff: Actor(id: 'u2', code: 'LIB002', fullName: 'Phạm Quốc Bảo'),
          status: ScheduleStatus.active,
        ),
        ShiftAssignment(
          id: 'a3',
          staff: Actor(id: 'u3', code: 'LIB004', fullName: 'Nguyễn Hải Yến'),
          status: ScheduleStatus.cancelled,
        ),
      ];
}

MyShift _shift(String id, String name, DateTime start, Duration length,
        {ScheduleStatus status = ScheduleStatus.active, String? reason}) =>
    MyShift(
      shift: Shift(
        id: id,
        name: name,
        startsAt: start,
        endsAt: start.add(length),
        status: status,
        cancellationReason: reason,
      ),
      assignment: const ShiftAssignment(
        id: 'mine',
        staff: Actor(id: 'u1', code: 'LIB001', fullName: 'Lê Thu Trang'),
        status: ScheduleStatus.active,
      ),
    );

Future<void> _pump(WidgetTester tester, _FakeShiftsRepository repo, {Size size = const Size(1440, 1200)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myShiftsRepositoryProvider.overrideWithValue(repo),
        tokenStorageProvider.overrideWithValue(_EmptyTokenStorage()),
      ],
      child: const MaterialApp(home: Scaffold(body: MyShiftsScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final weekStart = Fmt.startOfVietnamWeek(DateTime.now());
  // Monday 07:30, Tuesday 13:00, Friday 22:00 → Saturday 06:00 (Vietnam time).
  final monday = weekStart.add(const Duration(hours: 7, minutes: 30));
  final tuesday = weekStart.add(const Duration(days: 1, hours: 13));
  final friday = weekStart.add(const Duration(days: 4, hours: 22));
  final thursday = weekStart.add(const Duration(days: 3, hours: 8));

  final thisWeek = [
    _shift('s1', 'Ca sáng', monday, const Duration(hours: 4, minutes: 30)),
    _shift('s2', 'Ca chiều', tuesday, const Duration(hours: 5)),
    _shift('s3', 'Ca đêm kiểm kê', friday, const Duration(hours: 8)),
    _shift('s4', 'Ca hội thảo', thursday, const Duration(hours: 4),
        status: ScheduleStatus.cancelled, reason: 'Hội thảo bị hoãn'),
  ];

  testWidgets('lists this week, including overnight and cancelled shifts', (tester) async {
    final repo = _FakeShiftsRepository(thisWeek);
    await _pump(tester, repo);

    expect(repo.requestedRanges.single, (weekStart, weekStart.add(const Duration(days: 7))));
    expect(find.text(Fmt.weekRange(weekStart)), findsOneWidget);
    expect(find.text('Ca sáng'), findsOneWidget);
    expect(find.textContaining('07:30 – 12:00'), findsOneWidget);
    expect(find.textContaining('22:00 Thứ Sáu'), findsOneWidget);
    expect(find.textContaining('→ 06:00 Thứ Bảy'), findsOneWidget);
    expect(find.text('Đã hủy'), findsOneWidget);
  });

  testWidgets('navigates weeks and shows the empty state', (tester) async {
    final repo = _FakeShiftsRepository(thisWeek);
    await _pump(tester, repo);

    await tester.tap(find.text('Tuần sau'));
    await tester.pumpAndSettle();

    final next = weekStart.add(const Duration(days: 7));
    expect(repo.requestedRanges.last.$1, next);
    expect(find.text(Fmt.weekRange(next)), findsOneWidget);
    expect(find.text('Bạn chưa được phân ca trong tuần này'), findsOneWidget);

    await tester.tap(find.text('Hôm nay'));
    await tester.pumpAndSettle();
    expect(find.text('Ca sáng'), findsOneWidget);
  });

  testWidgets('week view places shifts in day columns', (tester) async {
    await _pump(tester, _FakeShiftsRepository(thisWeek));

    await tester.tap(find.text('Lịch tuần'));
    await tester.pumpAndSettle();

    expect(find.text('T2'), findsOneWidget);
    expect(find.text('CN'), findsOneWidget);
    expect(find.text('Ca chiều'), findsOneWidget);
    expect(find.text('Không có ca'), findsNWidgets(3), reason: 'Wednesday, Saturday and Sunday');
  });

  testWidgets('opens a read-only detail with active colleagues only', (tester) async {
    await _pump(tester, _FakeShiftsRepository(thisWeek));

    await tester.tap(find.text('Ca hội thảo'));
    await tester.pumpAndSettle();

    expect(find.text('Chi tiết ca trực'), findsOneWidget);
    expect(find.text('Hội thảo bị hoãn'), findsOneWidget);
    expect(find.text('Lê Thu Trang'), findsOneWidget);
    expect(find.text('Phạm Quốc Bảo'), findsOneWidget);
    expect(find.text('Nguyễn Hải Yến'), findsNothing);
  });

  testWidgets('fits a phone width without overflow', (tester) async {
    await _pump(tester, _FakeShiftsRepository(thisWeek), size: const Size(390, 844));

    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Lịch tuần'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
