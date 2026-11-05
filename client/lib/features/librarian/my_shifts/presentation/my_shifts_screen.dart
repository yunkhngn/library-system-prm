import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_segmented.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../../../shared/widgets/state_views.dart';
import '../application/my_shifts_providers.dart';
import '../data/models/shift.dart';
import 'widgets/shift_detail_sheet.dart';
import 'widgets/shift_tile.dart';
import 'widgets/shift_week_view.dart';

enum _ViewMode { list, week }

/// LIB-07 — The signed-in librarian's shifts, one week at a time. Read-only.
class MyShiftsScreen extends ConsumerStatefulWidget {
  const MyShiftsScreen({super.key});

  @override
  ConsumerState<MyShiftsScreen> createState() => _MyShiftsScreenState();
}

class _MyShiftsScreenState extends ConsumerState<MyShiftsScreen> {
  _ViewMode _mode = _ViewMode.list;

  @override
  Widget build(BuildContext context) {
    final weekStart = ref.watch(selectedWeekProvider);
    final week = ref.read(selectedWeekProvider.notifier);
    final shifts = ref.watch(myShiftsProvider);

    return PageScaffold(
      title: 'Ca trực của tôi',
      subtitle: 'Lịch phân ca do quản trị viên sắp xếp.',
      actions: [
        AppSegmented<_ViewMode>(
          segments: const [
            AppSegment(value: _ViewMode.list, label: 'Danh sách', icon: Icons.view_agenda_outlined),
            AppSegment(value: _ViewMode.week, label: 'Lịch tuần', icon: Icons.calendar_view_week_outlined),
          ],
          selected: _mode,
          onChanged: (mode) => setState(() => _mode = mode),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WeekNavigator(
            weekStart: weekStart,
            isThisWeek: week.isThisWeek,
            loading: shifts.isLoading,
            onPrevious: week.previous,
            onToday: week.thisWeek,
            onNext: week.next,
          ),
          const SizedBox(height: AppSpacing.md),
          AsyncValueView<List<MyShift>>(
            value: shifts,
            onRetry: () => ref.invalidate(myShiftsProvider),
            keepDataWhenInputsChange: false,
            loading: const Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: Center(child: CircularProgressIndicator()),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const Card(
                  child: EmptyState(
                    icon: Icons.event_busy_outlined,
                    title: 'Bạn chưa được phân ca trong tuần này',
                    message: 'Liên hệ quản trị viên nếu bạn cần được phân ca.',
                  ),
                );
              }
              return _mode == _ViewMode.list
                  ? _ShiftList(items: items)
                  : ShiftWeekView(
                      weekStart: weekStart,
                      items: items,
                      onTap: (item) => showShiftDetail(context, item),
                    );
            },
          ),
        ],
      ),
    );
  }
}

class _WeekNavigator extends StatelessWidget {
  const _WeekNavigator({
    required this.weekStart,
    required this.isThisWeek,
    required this.loading,
    required this.onPrevious,
    required this.onToday,
    required this.onNext,
  });

  final DateTime weekStart;
  final bool isThisWeek;
  final bool loading;
  final VoidCallback onPrevious;
  final VoidCallback onToday;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final spinner = loading
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.action),
          )
        : null;

    if (MediaQuery.sizeOf(context).width < AppSizes.compactBreakpoint) {
      return Row(
        children: [
          IconButton(
            tooltip: 'Tuần trước',
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: Text(Fmt.weekRange(weekStart), style: AppTypography.label)),
                if (spinner != null) ...[const SizedBox(width: AppSpacing.sm), spinner],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Tuần sau',
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
          AppButton(
            label: 'Hôm nay',
            variant: AppButtonVariant.secondary,
            onPressed: isThisWeek ? null : onToday,
          ),
        ],
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppButton(
          label: 'Tuần trước',
          icon: Icons.chevron_left,
          variant: AppButtonVariant.secondary,
          onPressed: onPrevious,
        ),
        AppButton(
          label: 'Hôm nay',
          variant: AppButtonVariant.secondary,
          onPressed: isThisWeek ? null : onToday,
        ),
        AppButton(
          label: 'Tuần sau',
          trailingIcon: Icons.chevron_right,
          variant: AppButtonVariant.secondary,
          onPressed: onNext,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(Fmt.weekRange(weekStart), style: AppTypography.h3),
        if (spinner != null) spinner,
      ],
    );
  }
}

class _ShiftList extends StatelessWidget {
  const _ShiftList({required this.items});

  final List<MyShift> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items) ...[
          ShiftTile(item: item, onTap: () => showShiftDetail(context, item)),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}
