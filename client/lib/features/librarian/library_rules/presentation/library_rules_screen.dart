import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_alert.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../system_config/application/system_config_provider.dart';
import '../../../system_config/data/models/system_config.dart';

/// LIB-08 — Read-only library rules. Only administrators can change them.
class LibraryRulesScreen extends ConsumerWidget {
  const LibraryRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(systemConfigProvider);

    return PageScaffold(
      title: 'Quy định thư viện',
      subtitle: 'Các quy định áp dụng khi ghi nhận ra vào thư viện.',
      trailing: IconButton(
        tooltip: 'Làm mới',
        icon: const Icon(Icons.refresh),
        onPressed: () => ref.invalidate(systemConfigProvider),
      ),
      child: AsyncValueView(
        value: config,
        onRetry: () => ref.invalidate(systemConfigProvider),
        loading: const Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
        data: (config) => _RulesBody(config: config),
      ),
    );
  }
}

class _RulesBody extends StatelessWidget {
  const _RulesBody({required this.config});

  final SystemConfig config;

  @override
  Widget build(BuildContext context) {
    final hours = _OpeningHoursCard(config: config);
    final limits = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RuleCard(
          icon: Icons.groups_outlined,
          title: 'Sức chứa tối đa',
          value: '${config.maxCapacity} người',
          caption: config.capacityEnforcement
              ? 'Không thể ghi nhận vào khi thư viện đã đủ người. '
                  'Cảnh báo gần đầy từ ${config.nearCapacityThreshold} người.'
              : 'Cảnh báo gần đầy từ ${config.nearCapacityThreshold} người.',
        ),
        const SizedBox(height: AppSpacing.md),
        _RuleCard(
          icon: Icons.hourglass_bottom_outlined,
          title: 'Thời gian lưu lại tối đa',
          value: config.maxSessionDurationMinutes == null
              ? 'Không giới hạn'
              : Fmt.duration(Duration(minutes: config.maxSessionDurationMinutes!)),
        ),
        const SizedBox(height: AppSpacing.md),
        _RuleCard(
          icon: Icons.timer_outlined,
          title: 'Khoảng cách giữa hai lần quét',
          value: '${config.scanCooldownSeconds} giây',
          caption: 'Lần quét lặp lại trong khoảng này sẽ được bỏ qua.',
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 840) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [hours, const SizedBox(height: AppSpacing.md), limits],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: hours),
                const SizedBox(width: AppSpacing.lg),
                Expanded(flex: 2, child: limits),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        const AppAlert(
          title: 'Ngoài giờ mở cửa',
          message: 'Ngoài giờ mở cửa vẫn có thể ghi nhận ra, nhưng không thể ghi nhận vào.',
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          [
            'Liên hệ quản trị viên nếu cần thay đổi quy định.',
            if (config.updatedAt != null) 'Cập nhật lần cuối lúc ${Fmt.dateTime(config.updatedAt!)}.',
          ].join(' '),
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _OpeningHoursCard extends StatelessWidget {
  const _OpeningHoursCard({required this.config});

  final SystemConfig config;

  @override
  Widget build(BuildContext context) {
    final today = Fmt.toVietnam(DateTime.now()).weekday;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CardTitle(icon: Icons.schedule_outlined, title: 'Giờ mở cửa'),
            const SizedBox(height: AppSpacing.md),
            for (var day = 1; day <= 7; day++)
              _OpeningRow(day: day, slot: config.slotFor(day), isToday: day == today),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Theo giờ Việt Nam (${config.timezone}).',
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpeningRow extends StatelessWidget {
  const _OpeningRow({required this.day, required this.slot, required this.isToday});

  final int day;
  final OpeningSlot? slot;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final closed = slot == null;
    final hours = closed
        ? 'Đóng cửa'
        : '${slot!.opensAt} – ${slot!.closesAt}${slot!.isAllDay ? ' (cả ngày)' : ''}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
      decoration: BoxDecoration(
        color: isToday ? AppColors.infoSurface : null,
        borderRadius: AppRadius.controlBorder,
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  Fmt.weekdayName(day),
                  style: AppTypography.label.copyWith(
                    fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                if (isToday) const StatusBadge.today(),
              ],
            ),
          ),
          Text(
            hours,
            style: AppTypography.bodyM.copyWith(
              color: closed ? AppColors.textSecondary : AppColors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.icon, required this.title, required this.value, this.caption});

  final IconData icon;
  final String title;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle(icon: icon, title: title),
            const SizedBox(height: AppSpacing.sm),
            Text(value, style: AppTypography.h2),
            if (caption != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(caption!, style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.navy),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(title, style: AppTypography.h3)),
      ],
    );
  }
}
