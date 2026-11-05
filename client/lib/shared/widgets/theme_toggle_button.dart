import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_mode_controller.dart';

/// Switches between the light and dark palette; the choice is remembered.
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(themeModeProvider);
    return IconButton(
      tooltip: dark ? 'Chuyển sang giao diện sáng' : 'Chuyển sang giao diện tối',
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          color: color ?? AppColors.textSecondary),
      onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
    );
  }
}
