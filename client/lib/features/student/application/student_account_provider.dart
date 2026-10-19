import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/models/user.dart';

final studentAccountProvider = FutureProvider.autoDispose<User>((ref) {
  final session = ref.watch(sessionControllerProvider);
  if (session is! Authenticated || session.user.role != UserRole.student) {
    throw StateError('Student session required');
  }
  return ref.watch(authRepositoryProvider).me();
});
