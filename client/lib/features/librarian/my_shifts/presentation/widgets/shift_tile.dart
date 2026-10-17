import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../shared/widgets/status_badge.dart';
import '../../data/models/shift.dart';

/// "07:30 – 12:00 · Thứ Hai 12/10", or for overnight shifts
/// "22:00 Thứ Sáu 16/10 → 06:00 Thứ Bảy 17/10".
String shiftTimeLabel(Shift shift) {
  if (shift.isOvernight) {
    return '${Fmt.time(shift.startsAt)} ${Fmt.weekdayDayMonth(shift.startsAt)}'
        ' → ${Fmt.time(shift.endsAt)} ${Fmt.weekdayDayMonth(shift.endsAt)}';
  }
  return '${Fmt.time(shift.startsAt)} – ${Fmt.time(shift.endsAt)} · ${Fmt.weekdayDayMonth(shift.startsAt)}';
}

/// List-mode row for LIB-07. Today's shift is highlighted; cancelled shifts
/// are muted and labelled so the state is not conveyed by color alone.
class ShiftTile extends StatelessWidget {
  const ShiftTile({super.key, required this.item, required this.onTap});

  final MyShift item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shift = item.shift;
    final cancelled = item.isCancelled;
    final today = !cancelled && Fmt.isSameVietnamDay(shift.startsAt, DateTime.now());
    final fg = cancelled ? AppColors.textSecondary : AppColors.textPrimary;

    return Material(
      color: today ? AppColors.infoSurface : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorder,
        side: BorderSide(color: today ? AppColors.action : AppColors.border),
      ),
      child: InkWell(
        borderRadius: AppRadius.cardBorder,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cancelled ? AppColors.neutralSurface : AppColors.infoSurface,
                  borderRadius: AppRadius.controlBorder,
                ),
                child: Icon(
                  shift.isOvernight ? Icons.dark_mode_outlined : Icons.schedule_outlined,
                  color: cancelled ? AppColors.textSecondary : AppColors.navy,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shift.name,
                      style: AppTypography.label.copyWith(
                        color: fg,
                        decoration: cancelled ? TextDecoration.lineThrough : null,
                        decorationColor: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      shiftTimeLabel(shift),
                      style: AppTypography.bodyM.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (cancelled)
                StatusBadge.cancelled(label: item.cancelledLabel!)
              else if (today)
                const StatusBadge.today(),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
