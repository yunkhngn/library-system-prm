import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../shared/widgets/app_button.dart';
import '../../auth/application/session_controller.dart';
import '../application/student_qr_controller.dart';

// Fixed dark-on-light in both themes: inverted or low-contrast codes fail on
// many scanners.
const _qrBackground = Color(0xFFFFFFFF);
const _qrForeground = Color(0xFF173B63);

class StudentQrScreen extends ConsumerStatefulWidget {
  const StudentQrScreen({super.key});

  @override
  ConsumerState<StudentQrScreen> createState() => _StudentQrScreenState();
}

class _StudentQrScreenState extends ConsumerState<StudentQrScreen>
    with WidgetsBindingObserver {
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    final visible = lifecycle == AppLifecycleState.resumed;
    ref.read(studentQrControllerProvider.notifier).setVisible(visible);
    setState(() => _visible = visible);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    if (session is! Authenticated) return const SizedBox.shrink();
    final state = ref.watch(studentQrControllerProvider);
    final user = session.user;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Text('Mã QR ra vào',
            style: AppTypography.h2.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.md),
        Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: Card(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: Column(children: [
              LayoutBuilder(builder: (context, constraints) {
                final size = constraints.maxWidth.clamp(0.0, 260.0);
                final qr = state.isActive
                    ? QrValidator.validate(
                        data: state.code!.token,
                        version: QrVersions.auto,
                        errorCorrectionLevel: QrErrorCorrectLevel.L,
                      ).qrCode
                    : null;
                final modules = qr == null ? 21 : 17 + 4 * qr.typeNumber;
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                      color: state.isActive
                          ? _qrBackground
                          : AppColors.neutralSurface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: AppRadius.controlBorder),
                  child: state.loading
                      ? const Center(
                          child: CircularProgressIndicator(
                              semanticsLabel: 'Đang tạo mã QR'))
                      : state.isActive && _visible
                          ? QrImageView(
                              data: state.code!.token, size: size,
                              // Four modules of white quiet zone, even for dense JWTs.
                              padding: EdgeInsets.all(size * 4 / (modules + 8)),
                              backgroundColor: _qrBackground,
                              eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: _qrForeground),
                              dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: _qrForeground),
                              semanticsLabel:
                                  'Mã QR ra vào cá nhân còn hiệu lực',
                              errorStateBuilder: (_, __) => const Center(
                                  child: Padding(
                                      padding: EdgeInsets.all(AppSpacing.md),
                                      child: Text(
                                          'Không hiển thị được mã QR. Hãy tạo mã mới.',
                                          textAlign: TextAlign.center))),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                  Icon(
                                      state.error != null
                                          ? Icons.wifi_off_outlined
                                          : Icons.close,
                                      size: 56,
                                      color: AppColors.textSecondary),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                      state.error != null
                                          ? 'Chưa có mã QR'
                                          : !_visible && state.isActive
                                              ? 'Mã QR tạm ẩn'
                                              : 'Mã đã hết hạn',
                                      style: AppTypography.h3,
                                      textAlign: TextAlign.center),
                                ]),
                );
              }),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName,
                            style: AppTypography.h3.copyWith(fontSize: 17)),
                        const SizedBox(height: AppSpacing.xs),
                        Text(user.code,
                            style:
                                AppTypography.caption.copyWith(fontSize: 13)),
                      ]),
                ),
              ),
              const SizedBox(height: 20),
              if (state.loading)
                Text('Đang tạo mã QR…', style: AppTypography.caption)
              else if (state.isActive)
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.schedule, size: 16, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Còn ${state.remainingSeconds} giây',
                      style: AppTypography.bodyL.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning)),
                ])
              else if (state.error == null)
                Text(
                    state.autoRenewStopped
                        ? 'Đã dừng tự đổi mã. Nhấn "Tạo mã mới" khi bạn ra cổng.'
                        : 'Mã cũ không còn sử dụng được.',
                    style: AppTypography.caption,
                    textAlign: TextAlign.center),
            ]),
          )),
        )),
        const SizedBox(height: AppSpacing.md),
        if (state.error != null) ...[
          AppAlert(
              title: 'Không tạo được mã QR',
              message: state.error,
              tone: AlertTone.error),
          const SizedBox(height: AppSpacing.md),
        ],
        if (!state.loading && (!state.isActive || state.canIssue)) ...[
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: AppButton(
                label: state.waitSeconds > 0
                    ? 'Thử lại sau ${state.waitSeconds} giây'
                    : 'Tạo mã mới',
                size: AppButtonSize.mobile,
                expand: true,
                onPressed: state.canIssue
                    ? () =>
                        ref.read(studentQrControllerProvider.notifier).issue()
                    : null,
              )),
          const SizedBox(height: AppSpacing.md),
        ],
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('Đưa mã này vào khung quét tại kiosk ở cổng thư viện.',
                style: AppTypography.bodyM)),
        const SizedBox(height: AppSpacing.lg),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
                'Mỗi mã dùng được một lần, hiệu lực 30 giây và tự đổi mã mới trước khi hết hạn.',
                style: AppTypography.caption)),
      ],
    );
  }
}
