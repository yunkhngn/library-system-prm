import 'package:client/features/access/data/models/access_session.dart';
import 'package:client/features/access/data/models/occupancy.dart';
import 'package:client/features/access/data/models/student_lookup.dart';
import 'package:client/features/access/data/models/subject.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Occupancy remaining and ratio', () {
    final snap = Occupancy(
      count: 187,
      maxCapacity: 250,
      nearCapacity: false,
      capacityEnforcement: false,
      revision: 4,
      asOf: DateTime.utc(2026, 10, 17, 7, 25),
    );
    expect(snap.remaining, 63);
    expect(snap.ratio, closeTo(0.748, 0.001));
  });

  test('Occupancy.fromJson and event conversion keep revision', () {
    final snap = Occupancy.fromJson({
      'count': 231,
      'maxCapacity': 250,
      'nearCapacity': true,
      'capacityEnforcement': true,
      'revision': 9,
      'asOf': '2026-10-17T07:25:00Z',
    });
    expect(snap.nearCapacity, isTrue);
    expect(snap.remaining, 19);

    final event = OccupancyEvent.fromJson({
      'eventId': 'e1',
      'occurredAt': '2026-10-17T07:26:00Z',
      'revision': 10,
      'count': 232,
      'maxCapacity': 250,
      'nearCapacity': true,
    });
    final next = event.toOccupancy(capacityEnforcement: snap.capacityEnforcement);
    expect(next.revision, 10);
    expect(next.count, 232);
    expect(next.capacityEnforcement, isTrue);
  });

  test('AccessSession explains automatic closure without a staff actor', () {
    final session = AccessSession.fromJson({
      'id': 's1',
      'subject': {'id': 'u1', 'kind': 'USER', 'code': 'SV001', 'fullName': 'Trần Minh Quân'},
      'checkInTime': '2026-10-16T10:00:00Z',
      'checkOutTime': '2026-10-16T15:00:00Z',
      'checkInMethod': 'FACE',
      'checkOutMethod': null,
      'checkoutReason': 'CLOSING_TIME',
      'durationSeconds': 18000,
    });
    expect(session.isOpen, isFalse);
    expect(session.autoCloseExplanation, contains('Đóng tự động do đến giờ đóng cửa'));
    expect(session.subject.kind, SubjectKind.user);
  });

  test('StudentLookup maps locked students and presence', () {
    final locked = StudentLookup.fromJson({
      'id': 'u2',
      'code': 'SV002',
      'fullName': 'Ngô Thanh Hà',
      'status': 'LOCKED',
      'isInside': false,
    });
    expect(locked.isLocked, isTrue);
    expect(locked.isInside, isFalse);
  });
}
