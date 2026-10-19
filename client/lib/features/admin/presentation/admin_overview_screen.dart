import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../access/application/occupancy_providers.dart';
import '../application/admin_providers.dart';
import 'widgets/admin_ui.dart';

class AdminOverviewScreen extends ConsumerWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final occupancy = ref.watch(occupancyProvider);
    return PageScaffold(
      title: 'Tổng quan',
      subtitle: 'Theo dõi tình trạng vận hành thư viện hôm nay',
      child: AsyncValueView(
        value: occupancy,
        onRetry: () => ref.read(occupancyProvider.notifier).reload(),
        data: (o) => LayoutBuilder(builder: (context, constraints) {
          final available = constraints.maxWidth;
          final cardWidth = available >= 900
              ? (available - 48) * .23
              : available >= 560
                  ? (available - 16) / 2
                  : available;
          final ratio = o.maxCapacity == 0 ? 0.0 : o.count / o.maxCapacity;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(spacing: 16, runSpacing: 16, children: [
                  SizedBox(
                    width:
                        available >= 900 ? (available - 48) * .31 : cardWidth,
                    child: AdminMetricCard(
                      label: 'Số người đang trong thư viện',
                      value: '${o.count} / ${o.maxCapacity}',
                      valueColor: AppColors.navy,
                      footer: AdminProgressBar(value: ratio),
                    ),
                  ),
                  ...ref.watch(dashboardAnalyticsProvider).maybeWhen(
                        data: (analytics) => [
                          SizedBox(
                              width: cardWidth,
                              child: AdminMetricCard(
                                  label: 'Lượt vào',
                                  value: '${analytics.totalCheckIns}')),
                          SizedBox(
                              width: cardWidth,
                              child: AdminMetricCard(
                                  label: 'Lượt ra',
                                  value: '${analytics.totalCheckOuts}')),
                          SizedBox(
                              width: cardWidth,
                              child: AdminMetricCard(
                                  label: 'Thời gian ở trung bình',
                                  value: analytics.averageStaySeconds == null
                                      ? '—'
                                      : '${(analytics.averageStaySeconds! / 60).round()} phút')),
                        ],
                        orElse: () => [
                          SizedBox(
                              width: cardWidth,
                              child: const AdminMetricCard(
                                  label: 'Lượt vào', value: '—')),
                          SizedBox(
                              width: cardWidth,
                              child: const AdminMetricCard(
                                  label: 'Lượt ra', value: '—')),
                          SizedBox(
                              width: cardWidth,
                              child: const AdminMetricCard(
                                  label: 'Thời gian ở trung bình', value: '—')),
                        ],
                      ),
                ]),
                const SizedBox(height: 24),
                Wrap(spacing: 20, runSpacing: 20, children: [
                  SizedBox(
                    width: available >= 760 ? available * .62 : available,
                    child: AdminCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AdminSectionTitle('Thiết bị Kiosk'),
                            const SizedBox(height: 18),
                            Wrap(spacing: 48, runSpacing: 8, children: [
                              Text('Đang hoạt động',
                                  style: AppTypography.bodyM.copyWith(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w500)),
                              Text('Theo dõi trong danh sách thiết bị',
                                  style: AppTypography.bodyM.copyWith(
                                      color: AppColors.textSecondary)),
                            ]),
                            const SizedBox(height: 14),
                            OutlinedButton(
                                onPressed: () => context.go(Routes.adminKiosks),
                                child: const Text('Quản lý thiết bị')),
                          ]),
                    ),
                  ),
                  SizedBox(
                    width: available >= 760 ? available * .34 : available,
                    child: AdminCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AdminSectionTitle('Truy cập nhanh'),
                            const SizedBox(height: 12),
                            _quick(context, 'Tài khoản', Routes.adminAccounts),
                            _quick(context, 'Phân ca nhân viên',
                                Routes.adminShifts),
                            _quick(context, 'Thống kê', Routes.adminAnalytics),
                            _quick(context, 'Cấu hình hệ thống',
                                Routes.adminConfig),
                          ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                AdminCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AdminSectionTitle('Tình trạng hiện diện'),
                        const SizedBox(height: 18),
                        Consumer(
                            builder: (context, ref, _) => AsyncValueView(
                                  value: ref.watch(dashboardPeopleProvider),
                                  onRetry: () =>
                                      ref.invalidate(dashboardPeopleProvider),
                                  data: (p) => Wrap(
                                      spacing: 72,
                                      runSpacing: 12,
                                      children: [
                                        _activity('Sinh viên', '${p.$1} người'),
                                        _activity(
                                            'Khách ngoài', '${p.$2} người'),
                                        _activity(
                                            'Còn trống', '${o.remaining} chỗ'),
                                      ]),
                                )),
                      ]),
                ),
              ]);
        }),
      ),
    );
  }

  Widget _quick(BuildContext context, String label, String route) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => context.go(route),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(6)),
            child: Text(label,
                style: AppTypography.caption.copyWith(
                    color: AppColors.action, fontWeight: FontWeight.w500)),
          ),
        ),
      );

  Widget _activity(String label, String value) => SizedBox(
        width: 210,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppTypography.label),
          const SizedBox(height: 4),
          Text(value, style: AppTypography.caption),
        ]),
      );
}
