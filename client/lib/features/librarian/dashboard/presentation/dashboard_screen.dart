import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/realtime/realtime_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_alert.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/method_badge.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../access/application/occupancy_providers.dart';
import '../../../access/data/models/occupant.dart';
import '../../../access/data/models/occupancy.dart';
import '../../../access/data/occupancy_repository.dart';
import '../../my_shifts/data/models/shift.dart';
import '../../my_shifts/data/my_shifts_repository.dart';
import '../../my_shifts/presentation/widgets/shift_tile.dart';

final _todayShiftsProvider = FutureProvider.autoDispose<List<MyShift>>((ref) {
  final start = Fmt.startOfVietnamDay(DateTime.now());
  return ref.watch(myShiftsRepositoryProvider).listMyShifts(
        from: start,
        to: start.add(const Duration(days: 1)),
      );
});

final _recentOccupantsProvider = FutureProvider.autoDispose<List<Occupant>>((ref) async {
  ref.watch(occupancyProvider);
  final page = await ref.watch(occupancyRepositoryProvider).listPeople(size: 5);
  return page.items;
});

/// LIB-01 — Live occupancy dashboard. No analytics charts.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final occupancy = ref.watch(occupancyProvider);
    final realtime = ref.watch(realtimeClientProvider);

    return ValueListenableBuilder(
      valueListenable: realtime.status,
      builder: (_, status, __) => PageScaffold(
        title: 'Tổng quan',
        subtitle: 'Số người đang trong thư viện, cập nhật trực tiếp.',
        actions: [_ConnectionChip(status: status)],
        trailing: IconButton(
          tooltip: 'Làm mới',
          icon: const Icon(Icons.refresh),
          onPressed: () {
            ref.read(occupancyProvider.notifier).reload();
            ref.invalidate(_recentOccupantsProvider);
            ref.invalidate(_todayShiftsProvider);
          },
        ),
        child: AsyncValueView(
          value: occupancy,
          onRetry: () => ref.read(occupancyProvider.notifier).reload(),
          data: (snap) => _DashboardBody(occupancy: snap, connection: status),
        ),
      ),
    );
  }
}

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({required this.status});
  final RealtimeStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      RealtimeStatus.connected => ('Đang kết nối trực tiếp', AppColors.success, Icons.circle),
      RealtimeStatus.connecting => ('Đang kết nối lại…', AppColors.warning, Icons.sync),
      RealtimeStatus.disconnected => ('Mất kết nối trực tiếp', AppColors.error, Icons.circle),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.occupancy, required this.connection});

  final Occupancy occupancy;
  final RealtimeStatus connection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shifts = ref.watch(_todayShiftsProvider);
    final recent = ref.watch(_recentOccupantsProvider);
    final stale = connection != RealtimeStatus.connected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (occupancy.nearCapacity)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: AppAlert(
              tone: AlertTone.warning,
              title: 'Thư viện sắp đạt sức chứa tối đa',
              message: 'Hãy ưu tiên ghi nhận ra và hạn chế khách mới nếu cần.',
            ),
          ),
        if (stale)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppAlert(
              tone: AlertTone.warning,
              title: 'Dữ liệu có thể đã cũ',
              message: 'Cập nhật lần cuối lúc ${Fmt.time(occupancy.asOf)}.',
              action: AppButton(
                label: 'Làm mới',
                variant: AppButtonVariant.secondary,
                onPressed: () => ref.read(occupancyProvider.notifier).reload(),
              ),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 840;
            final hero = _HeroCard(occupancy: occupancy, stale: stale);
            final actions = _QuickActions(todayShifts: shifts);
            if (stacked) {
              return Column(children: [hero, const SizedBox(height: AppSpacing.md), actions]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: hero),
                const SizedBox(width: AppSpacing.lg),
                Expanded(flex: 2, child: actions),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(child: Text('Mới vào gần đây', style: AppTypography.h3)),
            AppButton(
              label: 'Xem tất cả',
              variant: AppButtonVariant.link,
              onPressed: () => context.go(Routes.occupants),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AsyncValueView(
          value: recent,
          onRetry: () => ref.invalidate(_recentOccupantsProvider),
          data: (items) {
            if (items.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text('Hiện không có ai trong thư viện.', style: AppTypography.bodyM),
                ),
              );
            }
            return Card(
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      title: Text(items[i].subject.fullName, style: AppTypography.label),
                      subtitle: Text('${items[i].subject.code} · ${Fmt.duration(items[i].duration)}'),
                      leading: kindBadge(items[i].subject.kind),
                      trailing: Text(
                        Fmt.time(items[i].checkInTime),
                        style: AppTypography.bodyM.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Cập nhật lúc ${Fmt.time(occupancy.asOf)}',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.occupancy, required this.stale});
  final Occupancy occupancy;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final near = occupancy.nearCapacity;
    final numberColor = stale ? AppColors.textSecondary : AppColors.textPrimary;
    return Card(
      color: near && !stale ? AppColors.warningSurface : AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Số người đang trong thư viện', style: AppTypography.label.copyWith(color: AppColors.textSecondary)),
                if (near) ...[const SizedBox(width: AppSpacing.sm), const StatusBadge.nearCapacity()],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${occupancy.count}', style: AppTypography.display.copyWith(color: numberColor)),
                  TextSpan(
                    text: ' / ${occupancy.maxCapacity}',
                    style: AppTypography.h2.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: AppRadius.controlBorder,
              child: LinearProgressIndicator(
                value: occupancy.ratio.clamp(0, 1),
                minHeight: 8,
                color: near ? AppColors.warning : AppColors.action,
                backgroundColor: AppColors.border,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Còn ${occupancy.remaining} chỗ', style: AppTypography.bodyM),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.todayShifts});
  final AsyncValue<List<MyShift>> todayShifts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          label: 'Ghi nhận thủ công',
          icon: Icons.edit_note_outlined,
          expand: true,
          onPressed: () => context.go(Routes.manualAccess),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Thêm khách ngoài',
          icon: Icons.person_add_outlined,
          variant: AppButtonVariant.secondary,
          expand: true,
          onPressed: () => context.go(Routes.visitors),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: todayShifts.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => Text('Không tải được ca trực.', style: AppTypography.bodyM),
              data: (items) {
                final live = items.where((s) => !s.isCancelled).toList();
                if (live.isEmpty) {
                  return Text('Hôm nay bạn không có ca trực', style: AppTypography.bodyM.copyWith(color: AppColors.textSecondary));
                }
                final shift = live.first.shift;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ca trực hôm nay', style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(shift.name, style: AppTypography.label),
                    Text(shiftTimeLabel(shift), style: AppTypography.bodyM),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
