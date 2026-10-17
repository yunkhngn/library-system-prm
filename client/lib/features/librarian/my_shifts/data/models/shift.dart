import '../../../../../core/utils/formatters.dart';
import '../../../../../shared/models/actor.dart';

/// Backend shift and assignment statuses are both `ACTIVE` / `CANCELLED`.
enum ScheduleStatus {
  active,
  cancelled;

  static ScheduleStatus parse(String? value) =>
      value?.toUpperCase() == 'CANCELLED' ? cancelled : active;
}

/// Backend `ShiftDto` (fields the librarian UI needs).
class Shift {
  const Shift({
    required this.id,
    required this.name,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.cancellationReason,
  });

  factory Shift.fromJson(Map<String, dynamic> json) => Shift(
        id: json['id'] as String,
        name: json['name'] as String,
        startsAt: DateTime.parse(json['startsAt'] as String),
        endsAt: DateTime.parse(json['endsAt'] as String),
        status: ScheduleStatus.parse(json['status'] as String?),
        cancellationReason: json['cancellationReason'] as String?,
      );

  final String id;
  final String name;
  final DateTime startsAt;
  final DateTime endsAt;
  final ScheduleStatus status;
  final String? cancellationReason;

  Duration get duration => endsAt.difference(startsAt);

  /// Ends on a later Vietnam calendar day, e.g. 22:00 Fri → 06:00 Sat.
  bool get isOvernight => !Fmt.isSameVietnamDay(startsAt, endsAt);
}

/// Backend `AssignmentDto`.
class ShiftAssignment {
  const ShiftAssignment({required this.id, required this.staff, required this.status});

  factory ShiftAssignment.fromJson(Map<String, dynamic> json) => ShiftAssignment(
        id: json['id'] as String,
        staff: Actor.fromJson(json['staff'] as Map<String, dynamic>),
        status: ScheduleStatus.parse(json['status'] as String?),
      );

  final String id;
  final Actor staff;
  final ScheduleStatus status;
}

/// Backend `MyShift`: a shift plus the signed-in librarian's assignment to it.
class MyShift {
  const MyShift({required this.shift, required this.assignment});

  factory MyShift.fromJson(Map<String, dynamic> json) => MyShift(
        shift: Shift.fromJson(json['shift'] as Map<String, dynamic>),
        assignment: ShiftAssignment.fromJson(json['assignment'] as Map<String, dynamic>),
      );

  final Shift shift;
  final ShiftAssignment assignment;

  bool get isShiftCancelled => shift.status == ScheduleStatus.cancelled;
  bool get isAssignmentCancelled => assignment.status == ScheduleStatus.cancelled;

  /// Either the whole shift was cancelled or this librarian was unassigned.
  bool get isCancelled => isShiftCancelled || isAssignmentCancelled;

  String? get cancelledLabel {
    if (isShiftCancelled) return 'Đã hủy';
    if (isAssignmentCancelled) return 'Đã hủy phân công';
    return null;
  }
}
