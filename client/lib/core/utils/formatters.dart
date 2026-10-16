import 'package:intl/intl.dart';

/// Vietnamese display formats: DD/MM/YYYY and 24-hour HH:mm, in Vietnam time.
abstract final class Fmt {
  static const _vnOffset = Duration(hours: 7);

  static final _date = DateFormat('dd/MM/yyyy');
  static final _time = DateFormat('HH:mm');
  static final _dateTime = DateFormat('HH:mm dd/MM/yyyy');

  /// Converts any instant to Vietnam wall-clock time (UTC+7, no DST).
  static DateTime toVietnam(DateTime t) => t.toUtc().add(_vnOffset);

  static String date(DateTime t) => _date.format(toVietnam(t));
  static String time(DateTime t) => _time.format(toVietnam(t));
  static String dateTime(DateTime t) => _dateTime.format(toVietnam(t));

  /// "2 giờ 15 phút", "45 phút".
  static String duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '$m phút';
    return m == 0 ? '$h giờ' : '$h giờ $m phút';
  }
}
