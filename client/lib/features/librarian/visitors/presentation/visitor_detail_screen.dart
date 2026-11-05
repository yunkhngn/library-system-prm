import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/labeled_value.dart';
import '../../../../shared/widgets/method_badge.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../../../shared/widgets/staff_table.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../access/application/access_history_providers.dart';
import '../../../access/application/occupancy_providers.dart';
import '../../../access/data/models/access_session.dart';
import '../../../access/presentation/access_session_detail.dart';
import '../../../visitors/application/visitors_providers.dart';
import '../../../visitors/data/models/visitor.dart';

/// LIB-05 — Visitor detail, presence and access history. No edit/delete.
class VisitorDetailScreen extends ConsumerWidget {
  const VisitorDetailScreen({super.key, required this.visitorId});

  final String visitorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitor = ref.watch(visitorDetailProvider(visitorId));
    final history = ref.watch(visitorHistoryProvider(visitorId));
    final loaded = visitor.asData?.value;
    final inside = ref
            .watch(
              subjectIsInsideProvider((
                id: loaded?.id ?? visitorId,
                q: loaded?.referenceCode ?? '',
              )),
            )
            .asData
            ?.value ??
        false;

    return PageScaffold(
      title: 'Chi tiết khách ngoài',
      actions: [
        AppButton(
          label: 'Quay lại danh sách',
          variant: AppButtonVariant.ghost,
          icon: Icons.arrow_back,
          onPressed: () => context.go(Routes.visitors),
        ),
      ],
      child: AsyncValueView(
        value: visitor,
        onRetry: () => ref.invalidate(visitorDetailProvider(visitorId)),
        data: (v) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Khách ngoài / ${v.fullName}', style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.md),
            _ProfileCard(visitor: v, inside: inside),
            const SizedBox(height: AppSpacing.lg),
            Text('Lịch sử ra vào', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.sm),
            AsyncValueView(
              value: history,
              onRetry: () => ref.invalidate(visitorHistoryProvider(visitorId)),
              data: (page) => StaffTable<AccessSession>(
                columns: [
                  StaffColumn(header: 'Giờ vào', cell: (s) => Text(Fmt.dateTime(s.checkInTime))),
                  StaffColumn(
                    header: 'Phương thức vào',
                    cell: (s) => methodBadge(s.checkInMethod) ?? const Text('—'),
                  ),
                  StaffColumn(
                    header: 'Giờ ra',
                    cell: (s) => Text(s.checkOutTime == null ? '—' : Fmt.dateTime(s.checkOutTime!)),
                  ),
                  StaffColumn(header: 'Thời lượng', cell: (s) => Text(Fmt.duration(s.duration))),
                  StaffColumn(
                    header: 'Trạng thái',
                    cell: (s) => s.isOpen ? const StatusBadge.open() : const StatusBadge.closed(),
                  ),
                ],
                rows: page.items,
                page: 0,
                size: page.size,
                totalElements: page.totalElements,
                onPageChanged: (_) {},
                onRowTap: (s) => showAccessSessionDetail(context, s),
                empty: const StaffEmpty(
                  icon: Icons.history,
                  title: 'Chưa có lượt ra vào',
                  message: 'Ghi nhận thủ công sẽ xuất hiện tại đây.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.visitor, required this.inside});

  final Visitor visitor;
  final bool inside;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LabeledValue(label: 'Họ và tên', value: visitor.fullName),
            LabeledValue(label: 'Mã khách', value: visitor.referenceCode),
            LabeledValue(label: 'Ngày tạo', value: Fmt.dateTime(visitor.createdAt)),
            LabeledValue(
              label: 'Hiện diện',
              child: inside ? const StatusBadge.inside() : const StatusBadge.outside(),
            ),
            AppButton(
              label: inside ? 'Ghi nhận ra' : 'Ghi nhận vào',
              icon: inside ? Icons.logout : Icons.login,
              onPressed: () => context.go(
                Routes.manualAccessFor(
                  visitorId: visitor.id,
                  action: inside ? 'CHECK_OUT' : 'CHECK_IN',
                  code: visitor.referenceCode,
                  name: visitor.fullName,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
