import 'package:client/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Fmt.startOfVietnamWeek', () {
    // Monday 12/10/2026 00:00 in Vietnam is Sunday 11/10 17:00 UTC.
    final monday = DateTime.utc(2026, 10, 11, 17);

    test('returns Vietnam Monday midnight for a mid-week instant', () {
      expect(Fmt.startOfVietnamWeek(DateTime.utc(2026, 10, 14, 3)), monday);
    });

    test('treats Monday 00:30 Vietnam (still Sunday in UTC) as the new week', () {
      expect(Fmt.startOfVietnamWeek(DateTime.utc(2026, 10, 11, 17, 30)), monday);
    });

    test('treats Sunday 23:59 Vietnam as the same week', () {
      expect(Fmt.startOfVietnamWeek(DateTime.utc(2026, 10, 18, 16, 59)), monday);
    });

    test('rolls over at Monday 00:00 Vietnam', () {
      expect(
        Fmt.startOfVietnamWeek(DateTime.utc(2026, 10, 18, 17)),
        monday.add(const Duration(days: 7)),
      );
    });
  });

  test('weekRange omits the first year unless the week spans two years', () {
    expect(Fmt.weekRange(DateTime.utc(2026, 10, 11, 17)), '12/10 – 18/10/2026');
    expect(Fmt.weekRange(DateTime.utc(2025, 12, 28, 17)), '29/12/2025 – 04/01/2026');
  });

  test('weekday labels follow ISO numbering in Vietnam time', () {
    // 16/10/2026 22:00 Vietnam is a Friday.
    expect(Fmt.weekdayDayMonth(DateTime.utc(2026, 10, 16, 15)), 'Thứ Sáu 16/10');
    expect(Fmt.weekdayName(7), 'Chủ Nhật');
    expect(Fmt.weekdayShort(1), 'T2');
  });
}
