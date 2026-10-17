import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/network/api_error.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../shared/widgets/labeled_value.dart';
import '../../../../../shared/widgets/side_sheet.dart';
import '../../../../../shared/widgets/status_badge.dart';
import '../../../../auth/application/session_controller.dart';
import '../../application/my_shifts_providers.dart';
import '../../data/models/shift.dart';

Future<void> showShiftDetail(BuildContext context, MyShift item) => showSideSheet(
      context,
      title: 'Chi tiết ca trực',
      builder: (_) => ShiftDetail(item: item),
    );

/// Read-only shift detail: no clock-in, swap or leave actions (out of scope).
class ShiftDetail extends ConsumerWidget {
  const ShiftDetail({super.key, required this.item});

  final MyShift item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shift = item.shift;
    final session = ref.watch(sessionControllerProvider);
    final myId = session is Authenticated ? session.user.id : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(shift.name, style: AppTypography.h2),
        const SizedBox(height: AppSpacing.lg),
        LabeledValue(
          label: 'Trạng thái',
          child: Align(
            alignment: Alignment.centerLeft,
            child: item.isCancelled
                ? StatusBadge.cancelled(label: item.cancelledLabel!)
                : const StatusBadge(
                    label: 'Đã lên lịch',
                    tone: BadgeTone.success,
                    icon: Icons.event_available_outlined,
                  ),
          ),
        ),
        LabeledValue(
          label: 'Bắt đầu',
          value: '${Fmt.time(shift.startsAt)}, ${Fmt.longDate(shift.startsAt)}',
        ),
        LabeledValue(
          label: 'Kết thúc',
          value: '${Fmt.time(shift.endsAt)}, ${Fmt.longDate(shift.endsAt)}',
        ),
        LabeledValue(label: 'Thời lượng', value: Fmt.duration(shift.duration)),
        if (item.isShiftCancelled && (shift.cancellationReason?.isNotEmpty ?? false))
          LabeledValue(label: 'Lý do hủy', value: shift.cancellationReason),
        const Divider(height: AppSpacing.xl),
        const Text('Thủ thư cùng ca', style: AppTypography.h3),
        const SizedBox(height: AppSpacing.sm),
        _Colleagues(shiftId: shift.id, myId: myId),
      ],
    );
  }
}

class _Colleagues extends ConsumerWidget {
  const _Colleagues({required this.shiftId, required this.myId});

  final String shiftId;
  final String? myId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colleagues = ref.watch(shiftColleaguesProvider(shiftId));
    final muted = AppTypography.bodyM.copyWith(color: AppColors.textSecondary);

    return colleagues.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Row(
        children: [
          Expanded(
            child: Text(
              error is ApiException ? error.userMessage : 'Không tải được danh sách.',
              style: muted,
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(shiftColleaguesProvider(shiftId)),
            child: const Text('Thử lại'),
          ),
        ],
      ),
      data: (list) {
        if (list.isEmpty) return Text('Chưa có thủ thư nào được phân vào ca này.', style: muted);
        return Column(
          children: [
            for (final a in list)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.navy,
                  child: Text(
                    a.staff.initials,
                    style: AppTypography.caption.copyWith(color: Colors.white),
                  ),
                ),
                title: Text(
                  a.staff.id == myId ? '${a.staff.fullName} (Bạn)' : a.staff.fullName,
                  style: AppTypography.label,
                ),
                subtitle: Text(a.staff.code, style: AppTypography.caption),
              ),
          ],
        );
      },
    );
  }
}
