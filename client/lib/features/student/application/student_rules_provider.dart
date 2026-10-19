import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session_controller.dart';
import '../../auth/data/models/user.dart';
import '../../system_config/data/models/system_config.dart';
import '../../system_config/data/system_config_repository.dart';

final studentRulesProvider = FutureProvider.autoDispose<SystemConfig>((ref) {
  final session = ref.watch(sessionControllerProvider);
  if (session is! Authenticated || session.user.role != UserRole.student) {
    throw StateError('Student session required');
  }
  return ref.watch(systemConfigRepositoryProvider).fetch();
});
