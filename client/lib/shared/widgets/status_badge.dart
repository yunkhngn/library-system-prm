import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

enum BadgeTone { success, info, warning, error, neutral }

/// Status chips from Figma "04 Trạng thái & phương thức". Always pairs color
/// with an icon and a label so status is not conveyed by color alone.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.tone, this.icon});

  const StatusBadge.active({super.key})
      : label = 'Đang hoạt động',
        tone = BadgeTone.success,
        icon = Icons.check_circle_outline;
  const StatusBadge.inside({super.key})
      : label = 'Đang trong thư viện',
        tone = BadgeTone.success,
        icon = Icons.login;
  const StatusBadge.outside({super.key})
      : label = 'Ngoài thư viện',
        tone = BadgeTone.neutral,
        icon = Icons.logout;
  const StatusBadge.nearCapacity({super.key})
      : label = 'Gần đầy',
        tone = BadgeTone.warning,
        icon = Icons.warning_amber_outlined;
  const StatusBadge.locked({super.key})
      : label = 'Đã khóa',
        tone = BadgeTone.error,
        icon = Icons.lock_outline;
  const StatusBadge.disconnected({super.key})
      : label = 'Mất kết nối',
        tone = BadgeTone.error,
        icon = Icons.wifi_off_outlined;
  const StatusBadge.face({super.key})
      : label = 'Khuôn mặt',
        tone = BadgeTone.info,
        icon = Icons.face_outlined;
  const StatusBadge.qr({super.key})
      : label = 'Mã QR',
        tone = BadgeTone.info,
        icon = Icons.qr_code_2_outlined;
  const StatusBadge.manual({super.key})
      : label = 'Thủ công',
        tone = BadgeTone.neutral,
        icon = Icons.edit_note_outlined;
  const StatusBadge.cancelled({super.key, this.label = 'Đã hủy'})
      : tone = BadgeTone.neutral,
        icon = Icons.block;
  const StatusBadge.today({super.key})
      : label = 'Hôm nay',
        tone = BadgeTone.info,
        icon = Icons.today_outlined;

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      BadgeTone.success => (AppColors.successSurface, AppColors.success),
      BadgeTone.info => (AppColors.infoSurface, AppColors.action),
      BadgeTone.warning => (AppColors.warningSurface, AppColors.warning),
      BadgeTone.error => (AppColors.errorSurface, AppColors.error),
      BadgeTone.neutral => (AppColors.neutralSurface, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(label, style: AppTypography.caption.copyWith(color: fg, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
