import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Centered card with brand header, shared by AUTH-01, AUTH-02 and AUTH-05.
class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.local_library_outlined, size: 40, color: AppColors.navy),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Library Access',
                        style: AppTypography.h3.copyWith(color: AppColors.navy),
                      ),
                      Text('Hệ thống ghi nhận ra vào thư viện', style: AppTypography.caption),
                      const SizedBox(height: AppSpacing.lg),
                      Text(title, style: AppTypography.h2),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          subtitle!,
                          style: AppTypography.bodyM.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
