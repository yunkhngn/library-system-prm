import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../access/data/models/access_result.dart';
import '../../access/data/models/subject.dart';
import '../application/kiosk_controller.dart';
import 'kiosk_camera.dart';
import 'kiosk_qr_scanner.dart';
import 'kiosk_ready_screen.dart';

class KioskScreen extends ConsumerStatefulWidget {
  const KioskScreen({super.key});
  @override
  ConsumerState<KioskScreen> createState() => _KioskScreenState();
}

class _KioskScreenState extends ConsumerState<KioskScreen> {
  Timer? _clock;
  KioskCapture? _capture;
  bool _qrOpen = false;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(kioskControllerProvider).restore());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(kioskControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
          child: Column(children: [
        _Header(
          name: state.session?.name,
          isExit: state.session?.isExit,
          onDisconnect:
              state.session != null && !state.busy ? _disconnect : null,
        ),
        Expanded(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1250),
                  child: _body(state))),
        )),
      ])),
    );
  }

  Widget _body(KioskController state) {
    final session = state.session;
    final faceEnabled = session?.faceEnabled ?? false;
    final showError = state.error != null && state.phase != KioskPhase.failure;

    Widget? panel;
    if (state.phase == KioskPhase.success && state.result != null) {
      panel = _SuccessContent(result: state.result!, onDone: state.reset);
    } else if (state.phase == KioskPhase.failure) {
      final pending = state.pendingKey != null;
      panel = _FailureContent(
        message: state.error?.userMessage ?? 'Vui lòng thử lại.',
        uncertain: pending,
        onPrimary: pending ? state.checkPending : state.reset,
        onQr: faceEnabled && state.canScan ? _openQr : null,
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (showError) ...[
        _ErrorBanner(message: state.error!.userMessage),
        const SizedBox(height: 16),
      ],
      KioskReadyScreen(
        camera: session == null
            ? const SizedBox.shrink()
            : !faceEnabled
                ? KioskQrScanner(
                    key: const ValueKey('kiosk-qr-scanner'),
                    enabled: state.canScan &&
                        state.phase == KioskPhase.ready &&
                        !_qrOpen,
                    onToken: state.scanQr,
                    onStatus: (status) => state.cameraStatus = status,
                  )
                : _qrOpen
                    ? const KioskCameraPaused()
                    : KioskCamera(
                        key: const ValueKey('kiosk-camera'),
                        onReady: (capture) {
                          _capture = capture;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() {});
                          });
                        },
                        onStatus: (status) => state.cameraStatus = status,
                      ),
        connected: session != null,
        restoring: state.restoring,
        online: state.online,
        busy: state.busy,
        faceEnabled: faceEnabled,
        isExit: session?.isExit ?? false,
        qrTtl: session?.qrTtlSeconds ?? 30,
        onConnect: _connect,
        onRetrySaved: state.hasSavedLogin ? state.retrySaved : null,
        onFace: state.canScan && _capture != null
            ? () => state.recognize(_capture!)
            : null,
        onQr: state.canScan ? _openQr : null,
        panelOverride: panel,
      ),
    ]);
  }

  Future<void> _connect() async {
    final credentials = await showDialog<(String, String)>(
        context: context, builder: (_) => const _ConnectDialog());
    if (credentials == null || !mounted) return;
    await ref
        .read(kioskControllerProvider)
        .connect(credentials.$1, credentials.$2);
  }

  Future<void> _disconnect() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Ngắt kết nối kiosk?',
      message:
          'Thông tin đăng nhập lưu trên máy này sẽ bị xóa. Lần sau cần nhập lại mã kiosk và khóa thiết bị.',
      confirmLabel: 'Ngắt kết nối',
      destructive: true,
    );
    if (confirmed && mounted) {
      await ref.read(kioskControllerProvider).disconnect();
    }
  }

  Future<void> _openQr() async {
    final state = ref.read(kioskControllerProvider);
    if (_qrOpen || !state.canScan) return;
    // QR-only kiosks already scan continuously, so the dialog only offers
    // manual entry and must not compete for the camera.
    final withCamera = state.session?.faceEnabled ?? false;
    setState(() => _qrOpen = true);
    final token = await showDialog<String>(
        context: context, builder: (_) => _QrDialog(withCamera: withCamera));
    if (!mounted) return;
    setState(() => _qrOpen = false);
    if (token != null && token.trim().isNotEmpty) {
      await ref.read(kioskControllerProvider).scanQr(token);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({this.name, this.isExit, this.onDisconnect});
  final String? name;
  final bool? isExit;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final wide = MediaQuery.sizeOf(context).width > 700;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 12, 12),
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(children: [
        Icon(Icons.local_library_outlined, color: AppColors.navy, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Thư viện Trung tâm',
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                        color: AppColors.navy, fontWeight: FontWeight.w700)),
                Text(name ?? 'Thiết bị kiosk',
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption),
              ]),
        ),
        if (wide && isExit != null) ...[
          KioskGateChip(isExit: isExit!),
          const SizedBox(width: 24),
        ],
        Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(Fmt.time(now),
                  style: AppTypography.h3.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()])),
              Text(Fmt.date(now), style: AppTypography.caption),
            ]),
        const SizedBox(width: 4),
        if (onDisconnect != null)
          PopupMenuButton<String>(
            tooltip: 'Tùy chọn thiết bị',
            icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
            onSelected: (_) => onDisconnect!(),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'disconnect',
                child: Row(children: [
                  Icon(Icons.link_off, size: 18),
                  SizedBox(width: 10),
                  Text('Ngắt kết nối thiết bị'),
                ]),
              ),
            ],
          )
        else
          const SizedBox(width: 12),
      ]),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.errorSurface,
          borderRadius: AppRadius.controlBorder,
        ),
        child: Row(children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: AppTypography.bodyM.copyWith(color: AppColors.error))),
        ]),
      );
}

class _ResultIcon extends StatelessWidget {
  const _ResultIcon(this.icon, this.color, this.surface);
  final IconData icon;
  final Color color, surface;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(color: surface, shape: BoxShape.circle),
          child: Icon(icon, size: 52, color: color),
        ),
      );
}

class _SuccessContent extends StatelessWidget {
  const _SuccessContent({required this.result, required this.onDone});
  final AccessResult result;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final out = result.action == AccessAction.checkOut;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        _ResultIcon(
            Icons.check_rounded, AppColors.success, AppColors.successSurface),
        const SizedBox(height: 20),
        Text(out ? 'Tạm biệt!' : 'Chào mừng!',
            textAlign: TextAlign.center,
            style: AppTypography.h3.copyWith(color: AppColors.success)),
        const SizedBox(height: 4),
        Text(result.subject.fullName,
            textAlign: TextAlign.center,
            style: AppTypography.h2.copyWith(fontWeight: FontWeight.w700)),
        Text(result.subject.code,
            textAlign: TextAlign.center,
            style:
                AppTypography.bodyL.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.neutralSurface,
            borderRadius: AppRadius.controlBorder,
          ),
          child: Text(
            '${out ? 'Đã ghi nhận ra' : 'Đã ghi nhận vào'} lúc ${Fmt.time(result.occurredAt)} · ${result.method.label}',
            textAlign: TextAlign.center,
            style: AppTypography.label,
          ),
        ),
        const SizedBox(height: 20),
        Text('Màn hình sẽ tự quay lại sau vài giây.',
            textAlign: TextAlign.center, style: AppTypography.caption),
        const SizedBox(height: 4),
        Center(child: TextButton(onPressed: onDone, child: const Text('Xong'))),
      ],
    );
  }
}

class _FailureContent extends StatelessWidget {
  const _FailureContent({
    required this.message,
    required this.uncertain,
    required this.onPrimary,
    this.onQr,
  });

  final String message;
  final bool uncertain;
  final VoidCallback onPrimary;
  final VoidCallback? onQr;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _ResultIcon(
            uncertain ? Icons.sync_problem_outlined : Icons.close_rounded,
            uncertain ? AppColors.warning : AppColors.error,
            uncertain ? AppColors.warningSurface : AppColors.errorSurface,
          ),
          const SizedBox(height: 20),
          Text(uncertain ? 'Chưa rõ kết quả' : 'Chưa thể ghi nhận',
              textAlign: TextAlign.center,
              style: AppTypography.h2.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style:
                  AppTypography.bodyL.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 28),
          KioskButton(
            label: uncertain ? 'Kiểm tra kết quả' : 'Thử lại',
            icon: uncertain ? Icons.refresh : Icons.replay,
            onPressed: onPrimary,
          ),
          if (onQr != null) ...[
            const SizedBox(height: 12),
            KioskButton(
              label: 'Sử dụng mã QR',
              icon: Icons.qr_code_scanner,
              secondary: true,
              onPressed: onQr,
            ),
          ],
        ],
      );
}

class _ConnectDialog extends StatefulWidget {
  const _ConnectDialog();
  @override
  State<_ConnectDialog> createState() => _ConnectDialogState();
}

class _ConnectDialogState extends State<_ConnectDialog> {
  final _code = TextEditingController(), _credential = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _code.dispose();
    _credential.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, (_code.text.trim(), _credential.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Kết nối thiết bị kiosk'),
        content: SizedBox(
            width: 420,
            child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                        controller: _code,
                        autofocus: true,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                            labelText: 'Mã kiosk', hintText: 'VD: KIOSK-01'),
                        validator: (value) => (value?.trim().isEmpty ?? true)
                            ? 'Nhập mã kiosk do quản trị viên cấp'
                            : null),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: _credential,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        onFieldSubmitted: (_) => _submit(),
                        decoration:
                            const InputDecoration(labelText: 'Khóa thiết bị'),
                        validator: (value) => (value?.trim().length ?? 0) < 32
                            ? 'Khóa thiết bị không hợp lệ'
                            : null),
                    const SizedBox(height: 12),
                    Text(
                        'Thông tin được lưu trên máy này để kiosk tự kết nối lại khi tải lại trang.',
                        style: AppTypography.caption),
                  ],
                ))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(onPressed: _submit, child: const Text('Kết nối')),
        ],
      );
}

class _QrDialog extends StatefulWidget {
  const _QrDialog({required this.withCamera});
  final bool withCamera;
  @override
  State<_QrDialog> createState() => _QrDialogState();
}

class _QrDialogState extends State<_QrDialog> {
  final _text = TextEditingController();
  MobileScannerController? _scanner;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    if (widget.withCamera) _scanner = MobileScannerController();
  }

  void _submit(String? token) {
    if (_submitted || token == null || token.trim().isEmpty) return;
    _submitted = true;
    Navigator.pop(context, token.trim());
  }

  @override
  void dispose() {
    _text.dispose();
    final scanner = _scanner;
    if (scanner != null) unawaited(scanner.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 12, 0),
        title: Row(children: [
          Icon(
              widget.withCamera
                  ? Icons.qr_code_scanner
                  : Icons.keyboard_outlined,
              color: AppColors.action),
          const SizedBox(width: 10),
          Expanded(
              child: Text(widget.withCamera
                  ? 'Quét mã QR cá nhân'
                  : 'Nhập mã QR thủ công')),
          IconButton(
              tooltip: 'Đóng',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close)),
        ]),
        content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_scanner != null) ...[
                  Text('Đưa mã QR trong ứng dụng vào giữa khung.',
                      style: AppTypography.bodyM
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 14),
                  AspectRatio(
                      aspectRatio: 4 / 3,
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: ColoredBox(
                            color: const Color(0xFF1B2733),
                            child: Stack(fit: StackFit.expand, children: [
                              MobileScanner(
                                controller: _scanner,
                                onDetect: (capture) {
                                  if (capture.barcodes.isNotEmpty) {
                                    _submit(capture.barcodes.first.rawValue);
                                  }
                                },
                                errorBuilder: (context, _) =>
                                    const KioskScannerError(),
                              ),
                              IgnorePointer(
                                child: Center(
                                  child: FractionallySizedBox(
                                    widthFactor: .6,
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: CustomPaint(
                                          painter: KioskScanFrame()),
                                    ),
                                  ),
                                ),
                              ),
                            ]),
                          ))),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(child: Divider(color: AppColors.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('hoặc', style: AppTypography.caption),
                    ),
                    Expanded(child: Divider(color: AppColors.border)),
                  ]),
                  const SizedBox(height: 12),
                ] else ...[
                  Text(
                      'Dùng khi camera không đọc được mã: quét bằng đầu đọc QR cầm tay hoặc dán mã vào ô bên dưới.',
                      style: AppTypography.bodyM
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextField(
                    controller: _text,
                    autofocus: !widget.withCamera,
                    onSubmitted: _submit,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.keyboard_outlined),
                        labelText: 'Nhập mã từ đầu đọc QR')),
              ],
            ))),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng')),
          FilledButton(
              onPressed: () => _submit(_text.text),
              child: const Text('Ghi nhận')),
        ],
      );
}
