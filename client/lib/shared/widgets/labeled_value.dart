import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Read-only "label above value" pair used in detail cards and side sheets.
class LabeledValue extends StatelessWidget {
  const LabeledValue({super.key, required this.label, this.value, this.child})
      : assert(value != null || child != null);

  final String label;
  final String? value;

  /// Replaces [value] when the value needs a badge or rich content.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          child ?? Text(value!, style: AppTypography.bodyL),
        ],
      ),
    );
  }
}
