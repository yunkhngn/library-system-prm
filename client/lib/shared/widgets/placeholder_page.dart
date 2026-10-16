import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Temporary body for screens that are routed but not implemented yet.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.screenId, required this.title});

  final String screenId;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(screenId, style: AppTypography.caption.copyWith(color: AppColors.action)),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: AppTypography.h2, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text('Màn hình đang được phát triển', style: AppTypography.bodyM.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
