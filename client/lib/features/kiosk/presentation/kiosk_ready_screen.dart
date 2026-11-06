import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

const _kioskButtonHeight = 56.0;
const _paneColor = Color(0xFF1B2733);

/// Connected kiosk layout: the camera pane stays mounted for the whole
/// session (so the camera never switches off between people); only the
/// side panel changes between ready, result and error content.
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
      this.onRetrySaved,
      this.panelOverride,
      this.restoring = false,
      this.isExit = false,
      this.qrTtl = 30});
  final Widget camera;
  final bool connected, online, busy, faceEnabled, isExit, restoring;
  final int qrTtl;
  final VoidCallback onConnect;
  final VoidCallback? onFace, onQr;

  /// Set when a login is saved on this device but reconnecting failed.
  final VoidCallback? onRetrySaved;

  /// Replaces the ready panel, e.g. with a scan result.
  final Widget? panelOverride;

  @override
  Widget build(BuildContext context) {
    if (!connected) {
      return _SetupCard(
        busy: busy || restoring,
        restoring: restoring,
        onConnect: onConnect,
        onRetrySaved: onRetrySaved,
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      final height = wide
          ? (constraints.maxHeight.isFinite
              ? constraints.maxHeight.clamp(460.0, 680.0)
              : 560.0)
          : 360.0;
      final panel = KioskPanel(
        wide: wide,
        footer: KioskConnectionStatus(connected: true, online: online),
        child: panelOverride ??
            _ReadyContent(
              busy: busy,
              faceEnabled: faceEnabled,
              isExit: isExit,
              qrTtl: qrTtl,
              onFace: onFace,
              onQr: onQr,
            ),
      );
      if (!wide) {
        return Column(children: [
          SizedBox(height: height, child: camera),
          const SizedBox(height: 20),
          panel,
        ]);
      }
      return SizedBox(
        height: height,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(flex: 62, child: camera),
          const SizedBox(width: 20),
          Expanded(flex: 38, child: panel),
        ]),
      );
    });
  }
}

class KioskPanel extends StatelessWidget {
  const KioskPanel(
      {super.key, required this.wide, required this.child, this.footer});

  final bool wide;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (wide)
              Expanded(child: SingleChildScrollView(child: child))
            else
              child,
            if (footer != null) ...[
              const SizedBox(height: 20),
              Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 14),
              footer!,
            ],
          ],
        ),
      );
}

class _ReadyContent extends StatelessWidget {
  const _ReadyContent({
    required this.busy,
    required this.faceEnabled,
    required this.isExit,
    required this.qrTtl,
    this.onFace,
    this.onQr,
  });

  final bool busy, faceEnabled, isExit;
  final int qrTtl;
  final VoidCallback? onFace, onQr;

  @override
  Widget build(BuildContext context) {
    final verb = isExit ? 'ra' : 'vào';
    final title = busy ? 'Đang xử lý…' : 'Ghi nhận $verb thư viện';
    final hint = busy
        ? 'Vui lòng giữ nguyên vị trí trong giây lát.'
        : faceEnabled
            ? 'Nhìn thẳng vào camera rồi bấm “Bắt đầu nhận diện”. Chỉ một người đứng trước camera.'
            : 'Mở mục Mã QR trong ứng dụng thư viện và đưa mã vào khung camera. Kiosk tự nhận mã, không cần bấm nút.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
            alignment: Alignment.centerLeft,
            child: KioskGateChip(isExit: isExit)),
        const SizedBox(height: 20),
        Text(title,
            style: AppTypography.h2.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(hint,
            style:
                AppTypography.bodyL.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 28),
        if (busy)
          const ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(4)),
            child: LinearProgressIndicator(minHeight: 6),
          )
        else ...[
          if (faceEnabled) ...[
            KioskButton(
              label: 'Bắt đầu nhận diện',
              icon: Icons.face_retouching_natural_outlined,
              onPressed: onFace,
            ),
            const SizedBox(height: 12),
          ],
          KioskButton(
            label: faceEnabled ? 'Sử dụng mã QR' : 'Nhập mã thủ công',
            icon: faceEnabled ? Icons.qr_code_scanner : Icons.keyboard_outlined,
            secondary: true,
            onPressed: onQr,
          ),
          const SizedBox(height: 14),
          _Note(Icons.timer_outlined,
              'Mã QR cá nhân có hiệu lực trong $qrTtl giây.'),
          if (!faceEnabled) ...[
            const SizedBox(height: 6),
            const _Note(Icons.info_outline,
                'Nhận diện khuôn mặt chưa khả dụng trên thiết bị này.'),
          ],
        ],
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: AppTypography.caption)),
      ]);
}

/// Shown until the device has signed in with its kiosk credential.
class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.busy,
    required this.restoring,
    required this.onConnect,
    this.onRetrySaved,
  });

  final bool busy, restoring;
  final VoidCallback onConnect;
  final VoidCallback? onRetrySaved;

  @override
  Widget build(BuildContext context) {
    final reconnecting = restoring || (busy && onRetrySaved != null);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          margin: const EdgeInsets.only(top: 32),
          padding: const EdgeInsets.fromLTRB(32, 36, 32, 28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: AppColors.infoSurface, shape: BoxShape.circle),
              child: Icon(Icons.tablet_mac_outlined,
                  size: 34, color: AppColors.action),
            ),
            const SizedBox(height: 20),
            Text(
                reconnecting
                    ? 'Đang kết nối lại…'
                    : onRetrySaved != null
                        ? 'Không kết nối được máy chủ'
                        : 'Thiết bị chưa được kết nối',
                textAlign: TextAlign.center,
                style: AppTypography.h2.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(
                onRetrySaved != null
                    ? 'Kiosk đã lưu thông tin đăng nhập trên máy này và sẽ tự kết nối lại.'
                    : 'Nhập mã kiosk và khóa thiết bị do quản trị viên cấp trong mục Thiết bị Kiosk.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyL
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 28),
            if (onRetrySaved != null) ...[
              KioskButton(
                label: 'Thử kết nối lại',
                icon: Icons.refresh,
                loading: busy,
                onPressed: busy ? null : onRetrySaved,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: busy ? null : onConnect,
                child: const Text('Dùng mã kiosk khác'),
              ),
            ] else
              KioskButton(
                label: 'Kết nối thiết bị',
                icon: Icons.link,
                loading: busy,
                onPressed: busy ? null : onConnect,
              ),
            const SizedBox(height: 20),
            Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 14),
            const KioskConnectionStatus(connected: false, online: false),
          ]),
        ),
      ),
    );
  }
}

/// Placeholder while the camera is handed over to the QR scanner dialog.
class KioskCameraPaused extends StatelessWidget {
  const KioskCameraPaused({super.key});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ColoredBox(
          color: _paneColor,
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.qr_code_scanner,
                  size: 72, color: Colors.white38),
              const SizedBox(height: 12),
              Text('Camera đang dùng để quét mã QR',
                  style: AppTypography.bodyL.copyWith(color: Colors.white60)),
            ]),
          ),
        ),
      );
}

class KioskGateChip extends StatelessWidget {
  const KioskGateChip({super.key, required this.isExit});
  final bool isExit;

  @override
  Widget build(BuildContext context) {
    final color = isExit ? AppColors.warning : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isExit ? AppColors.warningSurface : AppColors.successSurface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isExit ? Icons.logout : Icons.login, size: 16, color: color),
        const SizedBox(width: 6),
        Text(isExit ? 'Cổng ra' : 'Cổng vào',
            style: AppTypography.label
                .copyWith(color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class KioskConnectionStatus extends StatelessWidget {
  const KioskConnectionStatus(
      {super.key, required this.connected, required this.online});
  final bool connected, online;

  @override
  Widget build(BuildContext context) {
    final color = online
        ? AppColors.success
        : connected
            ? AppColors.error
            : AppColors.textSecondary;
    return Row(children: [
      Icon(Icons.circle, size: 9, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
            online
                ? 'Đang kết nối trực tiếp'
                : connected
                    ? 'Mất kết nối máy chủ'
                    : 'Chưa kết nối thiết bị',
            style: AppTypography.caption.copyWith(color: color)),
      ),
    ]);
  }
}

class KioskButton extends StatelessWidget {
  const KioskButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.secondary = false,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool secondary, loading;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize:
          const WidgetStatePropertyAll(Size.fromHeight(_kioskButtonHeight)),
      shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppRadius.controlBorder)),
      textStyle: WidgetStatePropertyAll(
          AppTypography.bodyL.copyWith(fontWeight: FontWeight.w600)),
    );
    final child = loading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5))
        : Icon(icon, size: 22);
    return secondary
        ? OutlinedButton.icon(
            style: style.copyWith(
                side: WidgetStatePropertyAll(
                    BorderSide(color: AppColors.border, width: 1.5))),
            onPressed: onPressed,
            icon: child,
            label: Text(label))
        : FilledButton.icon(
            style: style,
            onPressed: onPressed,
            icon: child,
            label: Text(label));
  }
}
