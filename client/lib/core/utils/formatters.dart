import 'package:intl/intl.dart';

/// Vietnamese display formats: DD/MM/YYYY and 24-hour HH:mm, in Vietnam time.
abstract final class Fmt {
  static const _vnOffset = Duration(hours: 7);

  static final _date = DateFormat('dd/MM/yyyy');
  static final _dayMonth = DateFormat('dd/MM');
  static final _time = DateFormat('HH:mm');
  static final _dateTime = DateFormat('HH:mm dd/MM/yyyy');

  /// Index 1..7 follows ISO-8601 / [DateTime.weekday] (1 = Monday).
  static const _weekdays = [
    '',
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];
  static const _weekdaysShort = ['', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  /// Converts any instant to Vietnam wall-clock time (UTC+7, no DST).
  static DateTime toVietnam(DateTime t) => t.toUtc().add(_vnOffset);

  static String date(DateTime t) => _date.format(toVietnam(t));
  static String dayMonth(DateTime t) => _dayMonth.format(toVietnam(t));
  static String time(DateTime t) => _time.format(toVietnam(t));
  static String dateTime(DateTime t) => _dateTime.format(toVietnam(t));

  /// "Thứ Hai" for an ISO day number (1 = Monday … 7 = Sunday).
  static String weekdayName(int isoDay) => _weekdays[isoDay];
  static String weekdayShort(int isoDay) => _weekdaysShort[isoDay];

  /// "Thứ Hai 12/10" in Vietnam time.
  static String weekdayDayMonth(DateTime t) =>
      '${weekdayName(toVietnam(t).weekday)} ${dayMonth(t)}';

  /// "Thứ Hai, 12/10/2026" in Vietnam time.
  static String longDate(DateTime t) => '${weekdayName(toVietnam(t).weekday)}, ${date(t)}';

  /// "2 giờ 15 phút", "45 phút".
  static String duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '$m phút';
    return m == 0 ? '$h giờ' : '$h giờ $m phút';
  }

  /// UTC instant of Monday 00:00 (Vietnam time) of the week containing [t].
  static DateTime startOfVietnamWeek(DateTime t) {
    final vn = toVietnam(t);
    final monday = DateTime.utc(vn.year, vn.month, vn.day - (vn.weekday - 1));
    return monday.subtract(_vnOffset);
  }

  static bool isSameVietnamDay(DateTime a, DateTime b) {
    final x = toVietnam(a);
    final y = toVietnam(b);
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  /// "12/10 – 18/10/2026", or "29/12/2025 – 04/01/2026" across years.
  static String weekRange(DateTime weekStart) {
    final end = weekStart.add(const Duration(days: 6));
    final sameYear = toVietnam(weekStart).year == toVietnam(end).year;
    return '${sameYear ? dayMonth(weekStart) : date(weekStart)} – ${date(end)}';
  }
}
