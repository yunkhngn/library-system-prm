import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class AppSegment<T> {
  const AppSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Single-choice segmented control, e.g. "Tất cả / Sinh viên / Khách ngoài"
/// or "Danh sách / Lịch tuần".
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<AppSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      showSelectedIcon: false,
      segments: [
        for (final s in segments)
          ButtonSegment<T>(
            value: s.value,
            label: Text(s.label),
            icon: s.icon == null ? null : Icon(s.icon, size: 18),
          ),
      ],
      selected: {selected},
      onSelectionChanged: (values) => onChanged(values.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        minimumSize: const WidgetStatePropertyAll(Size(0, AppSizes.controlDesktop)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: AppSpacing.md)),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppRadius.controlBorder),
        ),
        side: const WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
        textStyle: const WidgetStatePropertyAll(AppTypography.label),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.infoSurface : AppColors.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? AppColors.action : AppColors.textPrimary,
        ),
      ),
    );
  }
}
