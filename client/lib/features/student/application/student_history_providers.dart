import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/paged.dart';
import '../../../core/utils/formatters.dart';
import '../../access/data/models/access_session.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/data/models/user.dart';
import '../data/student_history_repository.dart';
import 'student_home_provider.dart';

enum StudentHistoryRange { today, week, month, custom }

class StudentHistoryQuery {
  const StudentHistoryQuery(
      {required this.from,
      required this.to,
      this.range = StudentHistoryRange.month,
      this.page = 0});
  final DateTime from;
  final DateTime to;
  final StudentHistoryRange range;
  final int page;

  String get label => switch (range) {
        StudentHistoryRange.today => 'Hôm nay',
        StudentHistoryRange.week => '7 ngày qua',
        StudentHistoryRange.month => '30 ngày qua',
        StudentHistoryRange.custom =>
          '${Fmt.date(from)} – ${Fmt.date(to.subtract(const Duration(microseconds: 1)))}',
      };
}

// Keep the selected range/page when returning from a detail. Reset on account change.
final studentHistoryQueryProvider =
    NotifierProvider<StudentHistoryQueryController, StudentHistoryQuery>(
        StudentHistoryQueryController.new);

class StudentHistoryQueryController extends Notifier<StudentHistoryQuery> {
  @override
  StudentHistoryQuery build() {
    ref.watch(sessionControllerProvider
        .select((state) => state is Authenticated ? state.user.id : null));
    return _preset(StudentHistoryRange.month);
  }

  StudentHistoryQuery _preset(StudentHistoryRange range) {
    final now = ref.read(studentClockProvider)();
    final from = range == StudentHistoryRange.today
        ? Fmt.startOfVietnamDay(now)
        : now.subtract(
            Duration(days: range == StudentHistoryRange.week ? 7 : 30));
    return StudentHistoryQuery(from: from, to: now, range: range);
  }

  void select(StudentHistoryRange range) {
    if (range != StudentHistoryRange.custom) state = _preset(range);
  }

  void setRange(DateTime from, DateTime to) {
    if (!to.isAfter(from) || to.difference(from) > const Duration(days: 366)) {
      throw ArgumentError('Khoảng ngày phải từ 1 đến 366 ngày.');
    }
    state = StudentHistoryQuery(
        from: from, to: to, range: StudentHistoryRange.custom);
  }

  void setPage(int page) {
    if (page < 0) return;
    state = StudentHistoryQuery(
        from: state.from, to: state.to, range: state.range, page: page);
  }
}

void _requireStudent(SessionState session) {
  if (session is! Authenticated || session.user.role != UserRole.student) {
    throw StateError('Student session required');
  }
}

final studentHistoryProvider =
    FutureProvider.autoDispose<Paged<AccessSession>>((ref) {
  _requireStudent(ref.watch(sessionControllerProvider));
  final query = ref.watch(studentHistoryQueryProvider);
  return ref
      .watch(studentHistoryRepositoryProvider)
      .list(from: query.from, to: query.to, page: query.page);
});

final studentSessionDetailProvider =
    FutureProvider.autoDispose.family<AccessSession, String>((ref, id) {
  _requireStudent(ref.watch(sessionControllerProvider));
  return ref.watch(studentHistoryRepositoryProvider).detail(id);
});
