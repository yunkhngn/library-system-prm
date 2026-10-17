import 'package:client/features/librarian/my_shifts/data/models/shift.dart';
import 'package:client/features/librarian/my_shifts/presentation/widgets/shift_tile.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _myShiftJson({
  required String startsAt,
  required String endsAt,
  String shiftStatus = 'ACTIVE',
  String assignmentStatus = 'ACTIVE',
  String? reason,
}) =>
    {
      'shift': {
        'id': 's1',
        'name': 'Ca chiều',
        'startsAt': startsAt,
        'endsAt': endsAt,
        'status': shiftStatus,
        'cancellationReason': reason,
      },
      'assignment': {
        'id': 'a1',
        'status': assignmentStatus,
        'staff': {'id': 'u1', 'code': 'LIB001', 'fullName': 'Lê Thu Trang'},
      },
    };

void main() {
  test('parses a same-day shift and formats it in Vietnam time', () {
    final item = MyShift.fromJson(
      _myShiftJson(startsAt: '2026-10-13T06:00:00Z', endsAt: '2026-10-13T11:00:00Z'),
    );

    expect(item.shift.isOvernight, isFalse);
    expect(item.isCancelled, isFalse);
    expect(item.shift.duration, const Duration(hours: 5));
    expect(shiftTimeLabel(item.shift), '13:00 – 18:00 · Thứ Ba 13/10');
    expect(item.assignment.staff.initials, 'LT');
  });

  test('detects overnight shifts across the Vietnam date line', () {
    final item = MyShift.fromJson(
      _myShiftJson(startsAt: '2026-10-16T15:00:00Z', endsAt: '2026-10-16T23:00:00Z'),
    );

    expect(item.shift.isOvernight, isTrue);
    expect(shiftTimeLabel(item.shift), '22:00 Thứ Sáu 16/10 → 06:00 Thứ Bảy 17/10');
  });

  test('labels a cancelled shift and a cancelled assignment differently', () {
    final shiftCancelled = MyShift.fromJson(_myShiftJson(
      startsAt: '2026-10-13T06:00:00Z',
      endsAt: '2026-10-13T11:00:00Z',
      shiftStatus: 'CANCELLED',
      reason: 'Thư viện đóng cửa bảo trì',
    ));
    final unassigned = MyShift.fromJson(_myShiftJson(
      startsAt: '2026-10-13T06:00:00Z',
      endsAt: '2026-10-13T11:00:00Z',
      assignmentStatus: 'CANCELLED',
    ));

    expect(shiftCancelled.cancelledLabel, 'Đã hủy');
    expect(shiftCancelled.shift.cancellationReason, 'Thư viện đóng cửa bảo trì');
    expect(unassigned.cancelledLabel, 'Đã hủy phân công');
  });
}
