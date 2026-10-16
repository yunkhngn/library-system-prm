import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

enum AlertTone { info, success, warning, error }

/// Inline alert (Figma "Thông tin" / "Không tải được dữ liệu").
class AppAlert extends StatelessWidget {
  const AppAlert({
    super.key,
    required this.title,
    this.message,
    this.tone = AlertTone.info,
    this.action,
  });

  final String title;
  final String? message;
  final AlertTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (tone) {
      AlertTone.info => (AppColors.infoSurface, AppColors.action, Icons.info_outline),
      AlertTone.success => (AppColors.successSurface, AppColors.success, Icons.check_circle_outline),
      AlertTone.warning => (AppColors.warningSurface, AppColors.warning, Icons.warning_amber_outlined),
      AlertTone.error => (AppColors.errorSurface, AppColors.error, Icons.error_outline),
    };

    return Semantics(
      liveRegion: tone == AlertTone.error,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.controlBorder,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.label.copyWith(color: fg)),
                  if (message != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(message!, style: AppTypography.bodyM),
                  ],
                  if (action != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
