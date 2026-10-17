import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Read-only detail panel: slides in from the right on wide screens and
/// becomes a bottom sheet on phone widths.
Future<void> showSideSheet(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  final compact = MediaQuery.sizeOf(context).width < AppSizes.compactBreakpoint;

  if (compact) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, controller) => _SheetBody(
          title: title,
          controller: controller,
          child: builder(context),
        ),
      ),
    );
  }

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Đóng',
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, __) => Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: AppColors.surface,
        elevation: 8,
        child: SizedBox(
          width: 420,
          height: double.infinity,
          child: SafeArea(
            left: false,
            child: _SheetBody(title: title, child: builder(context)),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, _, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic))
          .animate(animation),
      child: child,
    ),
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.title, required this.child, this.controller});

  final String title;
  final Widget child;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
          child: Row(
            children: [
              Expanded(child: Text(title, style: AppTypography.h3)),
              IconButton(
                tooltip: 'Đóng',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: child,
          ),
        ),
      ],
    );
  }
}
