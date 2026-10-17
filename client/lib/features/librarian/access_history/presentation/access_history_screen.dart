import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_segmented.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/method_badge.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../../../shared/widgets/search_field.dart';
import '../../../../shared/widgets/staff_table.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../access/application/access_history_providers.dart';
import '../../../access/data/models/access_session.dart';
import '../../../access/data/models/subject.dart';
import '../../../access/presentation/access_session_detail.dart';

/// LIB-06 — Shared access history and detail drawer. No export/edit.
class AccessHistoryScreen extends ConsumerWidget {
  const AccessHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(historyQueryProvider);
    final list = ref.watch(accessHistoryProvider);
    final pageItems = list.asData?.value.items ?? const <AccessSession>[];
    final items = query.kind == null
        ? pageItems
        : pageItems.where((s) => s.subject.kind == query.kind).toList();

    return PageScaffold(
      title: 'Lịch sử ra vào',
      subtitle: 'Mặc định hiển thị các lượt trong ngày hôm nay (giờ Việt Nam).',
      actions: [
        AppSearchField(
          hint: 'Tên hoặc mã',
          initialValue: query.q,
          onChanged: (q) => ref.read(historyQueryProvider.notifier).search(q),
        ),
        AppButton(
          label: '${Fmt.date(query.from)} – ${Fmt.date(query.to.subtract(const Duration(seconds: 1)))}',
          icon: Icons.date_range,
          variant: AppButtonVariant.secondary,
          onPressed: () => _pickRange(context, ref, query),
        ),
        if (query.hasActiveFilters)
          AppButton(
            label: 'Xóa bộ lọc',
            variant: AppButtonVariant.ghost,
            onPressed: () => ref.read(historyQueryProvider.notifier).clear(),
          ),
      ],
      trailing: IconButton(
        tooltip: 'Làm mới',
        icon: const Icon(Icons.refresh),
        onPressed: () => ref.invalidate(accessHistoryProvider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              AppSegmented<String>(
                segments: const [
                  AppSegment(value: 'all', label: 'Tất cả'),
                  AppSegment(value: 'USER', label: 'Sinh viên'),
                  AppSegment(value: 'VISITOR', label: 'Khách ngoài'),
                ],
                selected: query.kind?.apiValue ?? 'all',
                onChanged: (v) => ref.read(historyQueryProvider.notifier).setKind(
                      v == 'all' ? null : SubjectKind.parse(v),
                    ),
              ),
              AppSegmented<String>(
                segments: const [
                  AppSegment(value: 'all', label: 'Mọi phương thức'),
                  AppSegment(value: 'FACE', label: 'Khuôn mặt'),
                  AppSegment(value: 'QR', label: 'Mã QR'),
                  AppSegment(value: 'MANUAL', label: 'Thủ công'),
                ],
                selected: query.method?.apiValue ?? 'all',
                onChanged: (v) => ref.read(historyQueryProvider.notifier).setMethod(
                      v == 'all' ? null : AccessMethod.tryParse(v),
                    ),
              ),
              AppSegmented<String>(
                segments: const [
                  AppSegment(value: 'all', label: 'Mọi trạng thái'),
                  AppSegment(value: 'open', label: 'Đang mở'),
                  AppSegment(value: 'closed', label: 'Đã đóng'),
                ],
                selected: query.isOpen == null
                    ? 'all'
                    : (query.isOpen! ? 'open' : 'closed'),
                onChanged: (v) => ref.read(historyQueryProvider.notifier).setOpen(
                      switch (v) { 'open' => true, 'closed' => false, _ => null },
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (query.kind != null)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                'API không lọc theo loại đối tượng; cột Loại và bộ lọc này chỉ áp dụng trên trang đang xem.',
                style: AppTypography.caption,
              ),
            ),
          AsyncValueView(
            value: list,
            keepDataWhenInputsChange: false,
            onRetry: () => ref.invalidate(accessHistoryProvider),
            data: (page) => StaffTable<AccessSession>(
              columns: [
                StaffColumn(header: 'Họ và tên', cell: (s) => Text(s.subject.fullName)),
                StaffColumn(header: 'Mã', cell: (s) => Text(s.subject.code)),
                StaffColumn(header: 'Loại', cell: (s) => kindBadge(s.subject.kind)),
                StaffColumn(header: 'Giờ vào', cell: (s) => Text(Fmt.time(s.checkInTime))),
                StaffColumn(
                  header: 'Phương thức vào',
                  cell: (s) => methodBadge(s.checkInMethod) ?? const Text('—'),
                ),
                StaffColumn(
                  header: 'Giờ ra',
                  cell: (s) => Text(s.checkOutTime == null ? '—' : Fmt.time(s.checkOutTime!)),
                ),
                StaffColumn(
                  header: 'Phương thức ra',
                  cell: (s) => methodBadge(s.checkOutMethod) ?? const Text('—'),
                ),
                StaffColumn(header: 'Thời lượng', cell: (s) => Text(Fmt.duration(s.duration))),
                StaffColumn(
                  header: 'Trạng thái',
                  cell: (s) => s.isOpen ? const StatusBadge.open() : const StatusBadge.closed(),
                ),
              ],
              rows: items,
              page: page.page,
              size: page.size,
              totalElements: page.totalElements,
              onPageChanged: (p) => ref.read(historyQueryProvider.notifier).setPage(p),
              onRowTap: (s) => showAccessSessionDetail(context, s),
              empty: StaffEmpty(
                icon: Icons.history,
                title: query.hasActiveFilters ? 'Không có kết quả' : 'Chưa có lượt ra vào hôm nay',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickRange(BuildContext context, WidgetRef ref, HistoryQuery query) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: Fmt.toVietnam(query.from),
        end: Fmt.toVietnam(query.to.subtract(const Duration(seconds: 1))),
      ),
    );
    if (picked == null) return;
    final from = Fmt.startOfVietnamDay(picked.start);
    final to = Fmt.startOfNextVietnamDay(picked.end);
    ref.read(historyQueryProvider.notifier).setRange(from, to);
  }
}
