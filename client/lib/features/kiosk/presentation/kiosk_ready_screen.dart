import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class KioskReadyScreen extends StatelessWidget {
  const KioskReadyScreen(
      {super.key,
      required this.camera,
      required this.connected,
      required this.online,
      required this.busy,
      required this.faceEnabled,
      required this.onConnect,
      this.onFace,
      this.onQr,
      this.isExit = false,
      this.qrTtl = 30});
  final Widget camera;
  final bool connected, online, busy, faceEnabled, isExit;
  final int qrTtl;
  final VoidCallback onConnect;
  final VoidCallback? onFace, onQr;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final height = wide
            ? (constraints.maxHeight.isFinite
                ? constraints.maxHeight.clamp(420.0, 660.0)
                : 500.0)
            : 380.0;
        final panel = Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border)),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    busy
                        ? 'Đang xử lý…'
                        : faceEnabled
                            ? 'Đưa khuôn mặt vào khung\nđể ghi nhận ${isExit ? 'ra' : 'vào'}'
                            : 'Sử dụng mã QR\nđể ghi nhận ${isExit ? 'ra' : 'vào'}',
                    style:
                        AppTypography.h2.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 18),
                const Text('Chỉ một người đứng trước camera',
                    style: AppTypography.bodyM),
                const SizedBox(height: 32),
                if (!connected) ...[
                  FilledButton(
                      onPressed: busy ? null : onConnect,
                      child: const Text('Kết nối thiết bị')),
                  const SizedBox(height: 12),
                  const Text('Nhập thông tin kiosk do quản trị viên cấp.',
                      style: AppTypography.caption),
                ] else ...[
                  if (faceEnabled) ...[
                    FilledButton(
                        onPressed: onFace,
                        child: const Text('Bắt đầu nhận diện')),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.icon(
                      onPressed: onQr,
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: const Text('Sử dụng mã QR')),
                  const SizedBox(height: 14),
                  Text('Mã QR cá nhân có hiệu lực trong $qrTtl giây.',
                      style: AppTypography.caption),
                  if (!faceEnabled) ...[
                    const SizedBox(height: 12),
                    const Text(
                        'Nhận diện khuôn mặt chưa khả dụng trên thiết bị này.',
                        style: AppTypography.caption),
                  ],
                ],
                if (wide) const Spacer() else const SizedBox(height: 28),
                Row(children: [
                  Icon(Icons.circle,
                      size: 9,
                      color:
                          online ? AppColors.success : AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          online
                              ? 'Đang kết nối trực tiếp'
                              : connected
                                  ? 'Mất kết nối máy chủ'
                                  : 'Chưa kết nối thiết bị',
                          style: AppTypography.caption.copyWith(
                              color: online
                                  ? AppColors.success
                                  : AppColors.textSecondary))),
                ]),
              ]),
        );
        if (!wide) {
          return Column(children: [
            SizedBox(height: height, child: camera),
            const SizedBox(height: 20),
            panel
          ]);
        }
        return SizedBox(
            height: height,
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(flex: 64, child: camera),
              const SizedBox(width: 20),
              Expanded(flex: 36, child: panel),
            ]));
      });
}
