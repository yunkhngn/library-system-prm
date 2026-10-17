import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_segmented.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/method_badge.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../../../shared/widgets/search_field.dart';
import '../../../../shared/widgets/side_sheet.dart';
import '../../../../shared/widgets/staff_table.dart';
import '../../../access/application/access_history_providers.dart';
import '../../../access/application/occupancy_providers.dart';
import '../../../access/data/models/occupant.dart';
import '../../../access/data/models/subject.dart';
import '../../../access/presentation/access_session_detail.dart';

/// LIB-02 — People currently inside the library.
class OccupantsScreen extends ConsumerWidget {
  const OccupantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(occupantQueryProvider);
    final list = ref.watch(occupantsProvider);

    return PageScaffold(
      title: 'Người đang trong thư viện',
      subtitle: 'Danh sách các phiên đang mở. Ghi nhận ra mở form thủ công, không checkout ngay.',
      actions: [
        AppSearchField(
          hint: 'Tìm theo tên hoặc mã',
          initialValue: query.q,
          onChanged: (q) => ref.read(occupantQueryProvider.notifier).search(q),
        ),
        AppSegmented<String>(
          segments: const [
            AppSegment(value: 'all', label: 'Tất cả'),
            AppSegment(value: 'USER', label: 'Sinh viên'),
            AppSegment(value: 'VISITOR', label: 'Khách ngoài'),
          ],
          selected: query.kind?.apiValue ?? 'all',
          onChanged: (v) => ref.read(occupantQueryProvider.notifier).setKind(
                v == 'all' ? null : SubjectKind.parse(v),
              ),
        ),
      ],
      trailing: IconButton(
        tooltip: 'Làm mới',
        icon: const Icon(Icons.refresh),
        onPressed: () => ref.invalidate(occupantsProvider),
      ),
      child: AsyncValueView(
        value: list,
        keepDataWhenInputsChange: false,
        onRetry: () => ref.invalidate(occupantsProvider),
        data: (page) => StaffTable<Occupant>(
          columns: [
            StaffColumn(header: 'Họ và tên', cell: (o) => Text(o.subject.fullName)),
            StaffColumn(header: 'Mã', cell: (o) => Text(o.subject.code)),
            StaffColumn(header: 'Loại', cell: (o) => kindBadge(o.subject.kind)),
            StaffColumn(header: 'Giờ vào', cell: (o) => Text(Fmt.time(o.checkInTime))),
            StaffColumn(header: 'Thời gian đã ở', cell: (o) => Text(Fmt.duration(o.duration))),
          ],
          rows: page.items,
          page: page.page,
          size: page.size,
          totalElements: page.totalElements,
          onPageChanged: (p) => ref.read(occupantQueryProvider.notifier).setPage(p),
          onRowTap: (o) => _openDetail(context, ref, o),
          rowActions: (o) => [
            AppButton(
              label: 'Ghi nhận ra',
              variant: AppButtonVariant.secondary,
              onPressed: () => context.go(
                Routes.manualAccessFor(
                  userId: o.subject.isVisitor ? null : o.subject.id,
                  visitorId: o.subject.isVisitor ? o.subject.id : null,
                  action: 'CHECK_OUT',
                  code: o.subject.code,
                  name: o.subject.fullName,
                ),
              ),
            ),
          ],
          empty: StaffEmpty(
            icon: Icons.groups_outlined,
            title: query.q.isEmpty && query.kind == null
                ? 'Hiện không có ai trong thư viện'
                : 'Không có kết quả',
            message: query.q.isEmpty ? null : 'Không tìm thấy người khớp “${query.q}”.',
          ),
        ),
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, WidgetRef ref, Occupant occupant) async {
    try {
      final session = await ref.read(accessSessionProvider(occupant.sessionId).future);
      if (context.mounted) await showAccessSessionDetail(context, session);
    } catch (_) {
      if (!context.mounted) return;
      await showSideSheet(
        context,
        title: occupant.subject.fullName,
        builder: (_) => _OccupantFallback(occupant: occupant),
      );
    }
  }
}

class _OccupantFallback extends StatelessWidget {
  const _OccupantFallback({required this.occupant});
  final Occupant occupant;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(occupant.subject.fullName, style: AppTypography.h2),
        const SizedBox(height: AppSpacing.md),
        Text('Mã: ${occupant.subject.code}'),
        Text('Vào lúc ${Fmt.dateTime(occupant.checkInTime)}'),
        Text('Đã ở ${Fmt.duration(occupant.duration)}'),
      ],
    );
  }
}
