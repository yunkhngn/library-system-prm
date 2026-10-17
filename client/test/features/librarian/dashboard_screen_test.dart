import 'package:client/core/network/paged.dart';
import 'package:client/core/realtime/realtime_client.dart';
import 'package:client/core/storage/token_storage.dart';
import 'package:client/core/utils/formatters.dart';
import 'package:client/features/access/application/occupancy_providers.dart';
import 'package:client/features/access/data/models/occupant.dart';
import 'package:client/features/access/data/models/occupancy.dart';
import 'package:client/features/access/data/models/subject.dart';
import 'package:client/features/access/data/occupancy_repository.dart';
import 'package:client/features/librarian/dashboard/presentation/dashboard_screen.dart';
import 'package:client/features/librarian/my_shifts/data/models/shift.dart';
import 'package:client/features/librarian/my_shifts/data/my_shifts_repository.dart';
import 'package:client/shared/models/actor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyTokens extends TokenStorage {
  @override
  Future<String?> readRefreshToken() async => null;
}

class _FakeOccupancy implements OccupancyRepository {
  _FakeOccupancy({required this.occupancy, this.people = const []});

  Occupancy occupancy;
  List<Occupant> people;

  @override
  Future<Occupancy> snapshot() async => occupancy;

  @override
  Future<Paged<Occupant>> listPeople({String q = '', SubjectKind? kind, int page = 0, int size = 20}) async =>
      Paged(items: people.take(size).toList(), page: 0, size: size, totalElements: people.length, totalPages: 1);
}

class _FakeShifts implements MyShiftsRepository {
  _FakeShifts(this.shifts);
  final List<MyShift> shifts;

  @override
  Future<List<MyShift>> listMyShifts({required DateTime from, required DateTime to}) async =>
      shifts.where((s) => s.shift.startsAt.isBefore(to) && s.shift.endsAt.isAfter(from)).toList();

  @override
  Future<List<ShiftAssignment>> listAssignments(String shiftId) async => const [];
}

Occupancy _snap({int count = 187, bool near = false}) => Occupancy(
      count: count,
      maxCapacity: 250,
      nearCapacity: near,
      capacityEnforcement: false,
      revision: 1,
      asOf: DateTime.utc(2026, 10, 17, 7, 25),
    );

Occupant _person() => Occupant(
      sessionId: 'sess-1',
      subject: const Subject(id: 'u1', kind: SubjectKind.user, code: 'SV001', fullName: 'Trần Minh Quân'),
      checkInTime: DateTime.utc(2026, 10, 17, 6, 40),
      duration: const Duration(minutes: 45),
      checkInMethod: AccessMethod.face,
    );

MyShift _todayShift() {
  final start = Fmt.startOfVietnamDay(DateTime.now()).add(const Duration(hours: 13));
  return MyShift(
    shift: Shift(
      id: 'sh1',
      name: 'Ca chiều',
      startsAt: start,
      endsAt: start.add(const Duration(hours: 5)),
      status: ScheduleStatus.active,
    ),
    assignment: const ShiftAssignment(
      id: 'a1',
      staff: Actor(id: 'lib', code: 'LIB001', fullName: 'Lê Thu Trang'),
      status: ScheduleStatus.active,
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required Occupancy occupancy,
  List<Occupant> people = const [],
  List<MyShift>? shifts,
  RealtimeStatus status = RealtimeStatus.connected,
}) async {
  tester.view.physicalSize = const Size(1440, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final tokens = _EmptyTokens();
  final realtime = RealtimeClient(tokens)..status.value = status;
  addTearDown(realtime.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokens),
        realtimeClientProvider.overrideWithValue(realtime),
        occupancyRepositoryProvider.overrideWithValue(_FakeOccupancy(occupancy: occupancy, people: people)),
        occupancyProvider.overrideWith(() => OccupancyController(connectRealtime: false)),
        myShiftsRepositoryProvider.overrideWithValue(_FakeShifts(shifts ?? [_todayShift()])),
      ],
      child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows occupancy, remaining seats, shift and recent people', (tester) async {
    await _pump(tester, occupancy: _snap(), people: [_person()]);

    expect(find.text('Số người đang trong thư viện'), findsOneWidget);
    expect(find.textContaining('187'), findsWidgets);
    expect(find.text('Còn 63 chỗ'), findsOneWidget);
    expect(find.text('Đang kết nối trực tiếp'), findsOneWidget);
    expect(find.text('Ghi nhận thủ công'), findsOneWidget);
    expect(find.text('Thêm khách ngoài'), findsOneWidget);
    expect(find.text('Ca chiều'), findsOneWidget);
    expect(find.text('Trần Minh Quân'), findsOneWidget);
    expect(find.text('Xem tất cả'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('near-capacity banner and stale reconnect variants', (tester) async {
    await _pump(
      tester,
      occupancy: _snap(count: 231, near: true),
      status: RealtimeStatus.disconnected,
    );

    expect(find.text('Thư viện sắp đạt sức chứa tối đa'), findsOneWidget);
    expect(find.text('Gần đầy'), findsOneWidget);
    expect(find.text('Mất kết nối trực tiếp'), findsOneWidget);
    expect(find.text('Dữ liệu có thể đã cũ'), findsOneWidget);
  });

  testWidgets('empty occupants and no shift today', (tester) async {
    await _pump(tester, occupancy: _snap(count: 0), people: const [], shifts: const []);

    expect(find.text('Hiện không có ai trong thư viện.'), findsOneWidget);
    expect(find.text('Hôm nay bạn không có ca trực'), findsOneWidget);
  });
}
