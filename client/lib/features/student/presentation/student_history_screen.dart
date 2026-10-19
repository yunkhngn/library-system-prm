import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/paged.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../../access/data/models/access_session.dart';
import '../application/student_history_providers.dart';
import '../application/student_home_provider.dart';

class StudentHistoryScreen extends ConsumerWidget {
  const StudentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(studentHistoryQueryProvider);
    final list = ref.watch(studentHistoryProvider);
    return RefreshIndicator(
      onRefresh: () async {
        if (query.range != StudentHistoryRange.custom) {
          ref.read(studentHistoryQueryProvider.notifier).select(query.range);
        }
        ref.invalidate(studentHistoryProvider);
        try {
          await ref.read(studentHistoryProvider.future);
        } catch (_) {/* Render provider error. */}
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.lg),
        children: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Row(children: [
                Expanded(
                    child: Text('Lịch sử ra vào',
                        style: AppTypography.h2
                            .copyWith(fontWeight: FontWeight.w700))),
                SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                        tooltip: 'Làm mới lịch sử',
                        onPressed: () {
                          if (query.range != StudentHistoryRange.custom) {
                            ref
                                .read(studentHistoryQueryProvider.notifier)
                                .select(query.range);
                          }
                          ref.invalidate(studentHistoryProvider);
                        },
                        icon: const Icon(Icons.refresh, size: 20))),
              ])),
          Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(
                    left: AppSpacing.xs, top: 14, bottom: AppSpacing.md),
                child: PopupMenuButton<StudentHistoryRange>(
                  tooltip: 'Lọc khoảng thời gian',
                  onSelected: (range) {
                    if (range == StudentHistoryRange.custom) {
                      _pickRange(context, ref, query);
                    } else {
                      ref
                          .read(studentHistoryQueryProvider.notifier)
                          .select(range);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: StudentHistoryRange.today,
                        child: Text('Hôm nay')),
                    PopupMenuItem(
                        value: StudentHistoryRange.week,
                        child: Text('7 ngày qua')),
                    PopupMenuItem(
                        value: StudentHistoryRange.month,
                        child: Text('30 ngày qua')),
                    PopupMenuItem(
                        value: StudentHistoryRange.custom,
                        child: Text('Chọn khoảng ngày')),
                  ],
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 160, minHeight: 38),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                        borderRadius: AppRadius.controlBorder),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(
                          child: Text(query.label,
                              style:
                                  AppTypography.label.copyWith(fontSize: 13))),
                      const SizedBox(width: AppSpacing.sm),
                      const Icon(Icons.arrow_drop_down, size: 16),
                    ]),
                  ),
                ),
              )),
          list.when(
            skipLoadingOnRefresh: false,
            skipLoadingOnReload: false,
            loading: () => const SizedBox(height: 240, child: LoadingState()),
            error: (error, _) => ErrorState(
                message: error is ApiException
                    ? error.userMessage
                    : 'Không tải được lịch sử. Vui lòng thử lại.',
                onRetry: () => ref.invalidate(studentHistoryProvider)),
            data: (page) => _HistoryList(
                page: page,
                now: ref.watch(studentClockProvider)(),
                onPage: (index) => ref
                    .read(studentHistoryQueryProvider.notifier)
                    .setPage(index)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickRange(
      BuildContext context, WidgetRef ref, StudentHistoryQuery query) async {
    final today = Fmt.toVietnam(ref.read(studentClockProvider)());
    DateTime calendar(DateTime instant) {
      final vn = Fmt.toVietnam(instant);
      return DateTime(vn.year, vn.month, vn.day);
    }

    final picked = await showDateRangePicker(
      context: context,
      locale: const Locale('vi', 'VN'),
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year, today.month, today.day),
      initialDateRange: DateTimeRange(
          start: calendar(query.from),
          end: calendar(query.to.subtract(const Duration(microseconds: 1)))),
      helpText: 'Chọn khoảng ngày',
      saveText: 'Áp dụng',
    );
    if (picked == null || !context.mounted) return;
    // Picker values are calendar dates, not instants in the machine timezone.
    final from =
        DateTime.utc(picked.start.year, picked.start.month, picked.start.day)
            .subtract(const Duration(hours: 7));
    final to =
        DateTime.utc(picked.end.year, picked.end.month, picked.end.day + 1)
            .subtract(const Duration(hours: 7));
    if (to.difference(from) > const Duration(days: 366)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn tối đa 366 ngày.')));
      return;
    }
    ref.read(studentHistoryQueryProvider.notifier).setRange(from, to);
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList(
      {required this.page, required this.now, required this.onPage});
  final Paged<AccessSession> page;
  final DateTime now;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (page.isEmpty)
          const EmptyState(
              title: 'Chưa có lượt ra vào',
              message: 'Không có lượt ra vào trong khoảng thời gian đã chọn.',
              icon: Icons.history),
        for (final session in page.items) ...[
          Card(
              child: InkWell(
            borderRadius: AppRadius.cardBorder,
            onTap: () => context.go(Routes.studentHistoryDetail(session.id)),
            child: Container(
                constraints: const BoxConstraints(minHeight: 108),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          Fmt.isSameVietnamDay(session.checkInTime, now)
                              ? 'Hôm nay'
                              : Fmt.date(session.checkInTime),
                          style: AppTypography.label
                              .copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                          'Vào ${Fmt.time(session.checkInTime)} → Ra ${session.checkOutTime == null ? '—' : Fmt.isSameVietnamDay(session.checkInTime, session.checkOutTime!) ? Fmt.time(session.checkOutTime!) : Fmt.dateTime(session.checkOutTime!)}',
                          style: AppTypography.bodyM.copyWith(fontSize: 13)),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                          session.isOpen
                              ? 'Đang trong thư viện'
                              : Fmt.duration(session.duration),
                          style: AppTypography.caption.copyWith(
                              color: session.isOpen
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w500)),
                    ])),
          )),
          const SizedBox(height: 18),
        ],
        if (page.totalPages > 1)
          Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppButton(
                    label: 'Trang trước',
                    variant: AppButtonVariant.secondary,
                    onPressed:
                        page.page > 0 ? () => onPage(page.page - 1) : null),
                Text('Trang ${page.page + 1}/${page.totalPages}',
                    style: AppTypography.caption),
                AppButton(
                    label: 'Trang sau',
                    variant: AppButtonVariant.secondary,
                    onPressed:
                        page.hasNext ? () => onPage(page.page + 1) : null),
              ]),
      ]);
}
