import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../../../shared/widgets/search_field.dart';
import '../../../../shared/widgets/staff_table.dart';
import '../../../visitors/application/visitors_providers.dart';
import '../../../visitors/data/models/visitor.dart';
import '../../../visitors/presentation/create_visitor_dialog.dart';

/// LIB-04 — External visitors directory and create dialog.
class VisitorsScreen extends ConsumerWidget {
  const VisitorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(visitorQueryProvider);
    final list = ref.watch(visitorsListProvider);

    return PageScaffold(
      title: 'Khách ngoài',
      subtitle: 'Khách không có tài khoản sinh viên. Tên trùng nhau được phân biệt bằng mã khách.',
      actions: [
        AppSearchField(
          hint: 'Tìm theo tên hoặc mã khách',
          initialValue: query.q,
          onChanged: (q) => ref.read(visitorQueryProvider.notifier).search(q),
        ),
        AppButton(
          label: 'Thêm khách ngoài',
          icon: Icons.person_add_outlined,
          onPressed: () => _create(context, ref),
        ),
      ],
      trailing: IconButton(
        tooltip: 'Làm mới',
        icon: const Icon(Icons.refresh),
        onPressed: () => ref.invalidate(visitorsListProvider),
      ),
      child: AsyncValueView(
        value: list,
        keepDataWhenInputsChange: false,
        onRetry: () => ref.invalidate(visitorsListProvider),
        data: (page) => StaffTable<Visitor>(
          columns: [
            StaffColumn(header: 'Họ và tên', cell: (v) => Text(v.fullName)),
            StaffColumn(header: 'Mã khách', cell: (v) => Text(v.referenceCode)),
            StaffColumn(header: 'Ngày tạo', cell: (v) => Text(Fmt.dateTime(v.createdAt))),
          ],
          rows: page.items,
          page: page.page,
          size: page.size,
          totalElements: page.totalElements,
          onPageChanged: (p) => ref.read(visitorQueryProvider.notifier).setPage(p),
          onRowTap: (v) => context.go(Routes.visitorDetail(v.id)),
          empty: StaffEmpty(
            icon: Icons.badge_outlined,
            title: query.q.isEmpty ? 'Chưa có khách ngoài' : 'Không có kết quả',
            message: query.q.isEmpty
                ? 'Thêm khách ngoài trước khi ghi nhận vào thư viện.'
                : 'Không tìm thấy khách khớp “${query.q}”.',
          ),
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final created = await showCreateVisitorDialog(context);
    if (created == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm ${created.fullName} (${created.referenceCode})'),
        action: SnackBarAction(
          label: 'Ghi nhận vào',
          onPressed: () => context.go(
            Routes.manualAccessFor(
              visitorId: created.id,
              action: 'CHECK_IN',
              code: created.referenceCode,
              name: created.fullName,
            ),
          ),
        ),
      ),
    );
  }
}
