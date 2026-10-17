import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/labeled_value.dart';
import '../../../shared/widgets/method_badge.dart';
import '../../../shared/widgets/side_sheet.dart';
import '../../../shared/widgets/status_badge.dart';
import '../data/models/access_session.dart';

Future<void> showAccessSessionDetail(BuildContext context, AccessSession session) => showSideSheet(
      context,
      title: 'Chi tiết lượt ra vào',
      builder: (_) => AccessSessionDetail(session: session),
    );

class AccessSessionDetail extends StatelessWidget {
  const AccessSessionDetail({super.key, required this.session});

  final AccessSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(s.subject.fullName, style: AppTypography.h2),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            kindBadge(s.subject.kind),
            if (s.isOpen) const StatusBadge.open() else const StatusBadge.closed(),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        LabeledValue(label: 'Mã', value: s.subject.code),
        LabeledValue(
          label: 'Giờ vào',
          value: Fmt.dateTime(s.checkInTime),
        ),
        LabeledValue(
          label: 'Phương thức vào',
          child: methodBadge(s.checkInMethod) ?? const Text('—'),
        ),
        if (s.checkInKiosk != null) LabeledValue(label: 'Kiosk vào', value: s.checkInKiosk!.name),
        if (s.checkInBy != null)
          LabeledValue(label: 'Nhân viên ghi nhận vào', value: '${s.checkInBy!.fullName} (${s.checkInBy!.code})'),
        if (s.manualReason != null && s.manualReason!.isNotEmpty)
          LabeledValue(label: 'Lý do vào', value: s.manualReason),
        const Divider(height: AppSpacing.xl),
        LabeledValue(
          label: 'Giờ ra',
          value: s.checkOutTime == null ? 'Đang trong thư viện' : Fmt.dateTime(s.checkOutTime!),
        ),
        if (s.checkOutMethod != null)
          LabeledValue(label: 'Phương thức ra', child: methodBadge(s.checkOutMethod)!),
        if (s.checkOutKiosk != null) LabeledValue(label: 'Kiosk ra', value: s.checkOutKiosk!.name),
        if (s.checkOutBy != null)
          LabeledValue(label: 'Nhân viên ghi nhận ra', value: '${s.checkOutBy!.fullName} (${s.checkOutBy!.code})'),
        if (s.checkOutManualReason != null && s.checkOutManualReason!.isNotEmpty)
          LabeledValue(label: 'Lý do ra', value: s.checkOutManualReason),
        if (s.autoCloseExplanation != null) LabeledValue(label: 'Đóng phiên', value: s.autoCloseExplanation),
        LabeledValue(label: 'Thời lượng', value: Fmt.duration(s.duration)),
      ],
    );
  }
}
