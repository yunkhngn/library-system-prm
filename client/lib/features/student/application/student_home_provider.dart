import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../access/data/models/access_session.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/models/user.dart';
import '../data/student_home_repository.dart';

class StudentHomeData {
  const StudentHomeData(
      {required this.user, required this.status, required this.recent});
  final User user;
  final StudentAccessStatus status;
  final List<AccessSession> recent;
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
  return StudentHomeData(
    user: results[0] as User,
    status: results[1] as StudentAccessStatus,
    recent: results[2] as List<AccessSession>,
  );
});

/// Injectable clock for deterministic Vietnamese dates and elapsed durations.
final studentClockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);
