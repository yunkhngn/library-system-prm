import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Standard body for a staff page inside the shell: title row with optional
/// actions, then [child]. Padding shrinks on phone widths.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.trailing,
    this.maxWidth = 1200,
    this.scrollable = true,
  });

  final String title;
  final String? subtitle;

  /// Wider controls; they wrap below the title on narrow screens.
  final List<Widget> actions;

  /// Small control (e.g. a refresh icon) that always stays beside the title.
  final Widget? trailing;
  final Widget child;
  final double maxWidth;

  /// Set to false when [child] scrolls itself (tables, lists).
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < AppSizes.compactBreakpoint;
        final padding = compact ? AppSpacing.md : AppSpacing.xl;

        // Without actions the title fills the row and [trailing] sits at the far end.
        final fillRow = actions.isEmpty;
        final titleText = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: compact ? AppTypography.h2 : AppTypography.h1),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                style: AppTypography.bodyM.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        );
        final titleBlock = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: fillRow ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (fillRow) Expanded(child: titleText) else Flexible(child: titleText),
            if (trailing != null) ...[const SizedBox(width: AppSpacing.sm), trailing!],
          ],
        );

        final header = fillRow
            ? titleBlock
            : Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  titleBlock,
                  Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: actions),
                ],
              );

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
          children: [
            header,
            SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
            if (scrollable) child else Expanded(child: child),
          ],
        );

        final constrained = Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: content,
          ),
        );

        return scrollable
            ? SingleChildScrollView(padding: EdgeInsets.all(padding), child: constrained)
            : Padding(padding: EdgeInsets.all(padding), child: constrained);
      },
    );
  }
}
