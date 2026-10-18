import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/system_config.dart';
import '../data/system_config_repository.dart';

/// Current library rules. Invalidate to reload.
final systemConfigProvider = FutureProvider.autoDispose<SystemConfig>(
  (ref) => ref.watch(systemConfigRepositoryProvider).fetch(),
);

class SystemConfigController extends AutoDisposeAsyncNotifier<void> {
  @override
  void build() {}

  Future<SystemConfig> save(Map<String, dynamic> patch) async {
    if (state.isLoading) throw StateError('Cấu hình đang được lưu.');
    state = const AsyncLoading();
    try {
      final result =
          await ref.read(systemConfigRepositoryProvider).update(patch);
      state = const AsyncData(null);
      ref.invalidate(systemConfigProvider);
      return result;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      rethrow;
    }
  }
}

final systemConfigControllerProvider =
    AutoDisposeAsyncNotifierProvider<SystemConfigController, void>(
        SystemConfigController.new);
