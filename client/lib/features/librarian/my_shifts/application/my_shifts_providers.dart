import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../data/models/shift.dart';
import '../data/my_shifts_repository.dart';

/// Monday 00:00 (Vietnam time) of the week shown in LIB-07, as a UTC instant.
class SelectedWeek extends Notifier<DateTime> {
  @override
  DateTime build() => Fmt.startOfVietnamWeek(DateTime.now());

  void previous() => state = state.subtract(const Duration(days: 7));
  void next() => state = state.add(const Duration(days: 7));
  void thisWeek() => state = Fmt.startOfVietnamWeek(DateTime.now());

  bool get isThisWeek => state == Fmt.startOfVietnamWeek(DateTime.now());
}

final selectedWeekProvider = NotifierProvider<SelectedWeek, DateTime>(SelectedWeek.new);

/// Shifts overlapping the selected week, oldest first.
final myShiftsProvider = FutureProvider.autoDispose<List<MyShift>>((ref) {
  final weekStart = ref.watch(selectedWeekProvider);
  return ref.watch(myShiftsRepositoryProvider).listMyShifts(
        from: weekStart,
        to: weekStart.add(const Duration(days: 7)),
      );
});

/// Librarians still assigned to a shift, for the read-only detail sheet.
final shiftColleaguesProvider =
    FutureProvider.autoDispose.family<List<ShiftAssignment>, String>((ref, shiftId) async {
  final assignments = await ref.watch(myShiftsRepositoryProvider).listAssignments(shiftId);
  return assignments.where((a) => a.status == ScheduleStatus.active).toList();
});
