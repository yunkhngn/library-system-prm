import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/utils/formatters.dart';
import '../../data/models/shift.dart';

/// Seven day columns (Monday → Sunday). Shifts sit on the day they start;
/// on narrow screens the columns scroll horizontally.
class ShiftWeekView extends StatelessWidget {
  const ShiftWeekView({
    super.key,
    required this.weekStart,
    required this.items,
    required this.onTap,
  });

  final DateTime weekStart;
  final List<MyShift> items;
  final ValueChanged<MyShift> onTap;

  static const _minColumnWidth = 140.0;

  @override
  Widget build(BuildContext context) {
    final days = [for (var i = 0; i < 7; i++) weekStart.add(Duration(days: i))];
    final now = DateTime.now();

    return LayoutBuilder(
      builder: (context, constraints) {
        final fits = constraints.maxWidth >= _minColumnWidth * 7 + AppSpacing.sm * 6;
        final columnWidth =
            fits ? (constraints.maxWidth - AppSpacing.sm * 6) / 7 : _minColumnWidth;

        final row = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < 7; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: columnWidth,
                child: _DayColumn(
                  day: days[i],
                  isToday: Fmt.isSameVietnamDay(days[i], now),
                  items: items.where((e) => Fmt.isSameVietnamDay(e.shift.startsAt, days[i])).toList(),
                  onTap: onTap,
                ),
              ),
            ],
          ],
        );

        return fits ? row : SingleChildScrollView(scrollDirection: Axis.horizontal, child: row);
      },
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.isToday,
    required this.items,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final List<MyShift> items;
  final ValueChanged<MyShift> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 160),
      decoration: BoxDecoration(
        color: isToday ? AppColors.infoSurface : AppColors.surface,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: isToday ? AppColors.action : AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            Fmt.weekdayShort(Fmt.toVietnam(day).weekday),
            style: AppTypography.caption.copyWith(
              color: isToday ? AppColors.action : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            Fmt.dayMonth(day),
            style: AppTypography.label.copyWith(color: isToday ? AppColors.action : null),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (items.isEmpty)
            Text('Không có ca', style: AppTypography.caption.copyWith(color: AppColors.textSecondary))
          else
            for (final item in items) ...[
              _ShiftChip(item: item, onTap: () => onTap(item)),
              const SizedBox(height: AppSpacing.xs),
            ],
        ],
      ),
    );
  }
}

class _ShiftChip extends StatelessWidget {
  const _ShiftChip({required this.item, required this.onTap});

  final MyShift item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shift = item.shift;
    final cancelled = item.isCancelled;
    final end = shift.isOvernight
        ? '${Fmt.time(shift.endsAt)} ${Fmt.weekdayShort(Fmt.toVietnam(shift.endsAt).weekday)}'
        : Fmt.time(shift.endsAt);

    return Material(
      color: cancelled ? AppColors.neutralSurface : AppColors.navy,
      borderRadius: AppRadius.controlBorder,
      child: InkWell(
        borderRadius: AppRadius.controlBorder,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (shift.isOvernight) ...[
                    Icon(
                      Icons.dark_mode_outlined,
                      size: 14,
                      color: cancelled ? AppColors.textSecondary : Colors.white,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Expanded(
                    child: Text(
                      shift.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: cancelled ? AppColors.textSecondary : Colors.white,
                        fontWeight: FontWeight.w600,
                        decoration: cancelled ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                '${Fmt.time(shift.startsAt)} – $end',
                style: AppTypography.caption.copyWith(
                  color: cancelled ? AppColors.textSecondary : Colors.white70,
                ),
              ),
              if (cancelled)
                Text(
                  item.cancelledLabel!,
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
