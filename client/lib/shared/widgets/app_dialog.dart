import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'app_button.dart';

/// Confirmation dialog. Use [destructive] for face deletion, account locking,
/// kiosk revocation, shift cancellation and assignment removal.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Hủy',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: AppTypography.h3),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Text(message, style: AppTypography.bodyM),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      actions: [
        AppButton(
          label: cancelLabel,
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: confirmLabel,
          variant: destructive ? AppButtonVariant.destructive : AppButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return result ?? false;
}
