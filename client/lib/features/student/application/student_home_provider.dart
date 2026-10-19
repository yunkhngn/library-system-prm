import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../access/data/models/access_session.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/models/user.dart';
import '../data/student_home_repository.dart';
import '../data/face_enrollment_repository.dart';

class StudentHomeData {
  const StudentHomeData(
      {required this.user,
      required this.status,
      required this.recent,
      this.faceEnrolledAt});
  final User user;
  final StudentAccessStatus status;
  final List<AccessSession> recent;
  final DateTime? faceEnrolledAt;
}

/// Also prevents a previous student's data surviving an account change.
final studentHomeProvider =
    FutureProvider.autoDispose<StudentHomeData>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  if (session is! Authenticated || session.user.role != UserRole.student) {
    throw StateError('Student session required');
  }
  final repository = ref.watch(studentHomeRepositoryProvider);
  final results = await Future.wait<Object>([
    ref.read(authRepositoryProvider).me(),
    repository.accessStatus(),
    repository.recentHistory().then((page) => page.items),
  ]);
  DateTime? enrolledAt;
  final user = results[0] as User;
  if (user.faceEnrolled) {
    try {
      enrolledAt = (await ref.read(faceEnrollmentRepositoryProvider).status())
          .enrolledAt;
    } catch (_) {
      // Optional metadata must not hide access status when unavailable.
    }
  }
  return StudentHomeData(
    user: results[0] as User,
    status: results[1] as StudentAccessStatus,
    recent: results[2] as List<AccessSession>,
    faceEnrolledAt: enrolledAt,
  );
});

/// Injectable clock for deterministic Vietnamese dates and elapsed durations.
final studentClockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);
