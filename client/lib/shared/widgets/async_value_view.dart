import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_error.dart';
import 'state_views.dart';

/// Renders an [AsyncValue] with the shared loading and error states.
/// A manual refresh keeps the previous data on screen.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    required this.onRetry,
    this.loading,
    this.keepDataWhenInputsChange = true,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback onRetry;
  final Widget? loading;

  /// Set to false when stale data would be misleading after the provider's
  /// inputs change (e.g. a different week is selected).
  final bool keepDataWhenInputsChange;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: keepDataWhenInputsChange,
      data: data,
      loading: () => loading ?? const LoadingState(),
      error: (error, _) => ErrorState(
        message: error is ApiException
            ? error.userMessage
            : 'Kiểm tra kết nối mạng và thử lại.',
        onRetry: onRetry,
      ),
    );
  }
}
