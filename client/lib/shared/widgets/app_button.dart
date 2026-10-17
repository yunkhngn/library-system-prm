import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

enum AppButtonVariant { primary, secondary, ghost, destructive, link }

enum AppButtonSize {
  desktop(AppSizes.controlDesktop),
  mobile(AppSizes.controlMobile),
  kiosk(AppSizes.controlKiosk);

  const AppButtonSize(this.height);
  final double height;
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.desktop,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;

  /// Shown after the label, e.g. a chevron on "Tuần sau".
  final IconData? trailingIcon;

  /// Disables the button and shows a spinner; prevents duplicate submission.
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (variant) {
      AppButtonVariant.primary => (AppColors.action, Colors.white, null),
      AppButtonVariant.secondary => (AppColors.surface, AppColors.textPrimary, AppColors.border),
      AppButtonVariant.ghost => (Colors.transparent, AppColors.textPrimary, null),
      AppButtonVariant.destructive => (AppColors.error, Colors.white, null),
      AppButtonVariant.link => (Colors.transparent, AppColors.action, null),
    };

    final textStyle = (size == AppButtonSize.kiosk ? AppTypography.h3 : AppTypography.label)
        .copyWith(color: fg, decoration: variant == AppButtonVariant.link ? TextDecoration.underline : null);

    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else if (icon != null)
          Icon(icon, size: 18, color: fg),
        if (loading || icon != null) const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text(label, style: textStyle, textAlign: TextAlign.center)),
        if (trailingIcon != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Icon(trailingIcon, size: 18, color: fg),
        ],
      ],
    );

    return SizedBox(
      height: variant == AppButtonVariant.link ? null : size.height,
      width: expand ? double.infinity : null,
      child: TextButton(
        onPressed: loading ? null : onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg == Colors.transparent ? null : bg.withValues(alpha: 0.5),
          disabledForegroundColor: fg.withValues(alpha: 0.7),
          padding: EdgeInsets.symmetric(
            horizontal: variant == AppButtonVariant.link ? 0 : AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.controlBorder,
            side: border == null ? BorderSide.none : BorderSide(color: border),
          ),
        ),
        child: child,
      ),
    );
  }
}
