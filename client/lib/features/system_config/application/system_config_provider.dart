import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/system_config.dart';
import '../data/system_config_repository.dart';

/// Current library rules. Invalidate to reload.
final systemConfigProvider = FutureProvider.autoDispose<SystemConfig>(
  (ref) => ref.watch(systemConfigRepositoryProvider).fetch(),
);
