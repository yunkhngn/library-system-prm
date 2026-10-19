import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class AdminCard extends StatelessWidget {
  const AdminCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(24)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: AppRadius.cardBorder,
        ),
        child: Padding(padding: padding, child: child),
      );
}

class AdminMetricCard extends StatelessWidget {
  const AdminMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.valueColor = AppColors.textPrimary,
    this.footer,
  });

  final String label;
  final String value;
  final Color valueColor;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => AdminCard(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          height: footer == null ? 66 : 88,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.caption.copyWith(fontSize: 13)),
              const SizedBox(height: 10),
              Text(
                value,
                style: AppTypography.h2.copyWith(
                  color: valueColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (footer != null) ...[const Spacer(), footer!],
            ],
          ),
        ),
      );
}

class AdminProgressBar extends StatelessWidget {
  const AdminProgressBar({
    super.key,
    required this.value,
    this.color = AppColors.action,
    this.height = 8,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: LinearProgressIndicator(
          value: value.clamp(0, 1),
          minHeight: height,
          backgroundColor: AppColors.neutralSurface,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      );
}

class AdminSectionTitle extends StatelessWidget {
  const AdminSectionTitle(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTypography.h3
            .copyWith(color: color, fontWeight: FontWeight.w600),
      );
}

class AdminFieldLabel extends StatelessWidget {
  const AdminFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: AppTypography.label.copyWith(fontSize: 13)),
      );
}
