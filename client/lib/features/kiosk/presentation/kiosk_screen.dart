import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../application/kiosk_controller.dart';
import 'kiosk_camera.dart';
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
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(kioskControllerProvider);
    final session = state.session;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
          child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(children: [
            Expanded(
                child: Text('Thư viện Trung tâm',
                    style: AppTypography.label.copyWith(
                        color: AppColors.navy, fontWeight: FontWeight.w700))),
            if (MediaQuery.sizeOf(context).width > 700) ...[
              Expanded(
                  child: Text(session?.name ?? 'Thiết bị kiosk',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textPrimary))),
              Text(session?.isExit == true ? 'Cổng ra' : 'Cổng vào',
                  style:
                      AppTypography.caption.copyWith(color: AppColors.action)),
              const SizedBox(width: 48),
            ],
            Column(children: [
              Text(Fmt.time(DateTime.now()), style: AppTypography.h3),
              Text(Fmt.date(DateTime.now()), style: AppTypography.caption),
            ]),
          ]),
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
    if (state.phase == KioskPhase.success) {
      return Padding(
          padding: const EdgeInsets.all(48),
          child: Text('${state.result!.action.label} thành công',
              style: AppTypography.h1));
    }
    if (state.phase == KioskPhase.failure) {
      return Column(children: [
        Text('Chưa thể ghi nhận', style: AppTypography.h1),
        Text(state.error?.userMessage ?? 'Vui lòng thử lại.'),
        FilledButton(
            onPressed:
                state.pendingKey != null ? state.checkPending : state.reset,
            child: Text(
                state.pendingKey != null ? 'Kiểm tra kết quả' : 'Thử lại')),
        if (state.canScan)
          OutlinedButton(
              onPressed: _openQr, child: const Text('Sử dụng mã QR')),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (state.error != null)
        Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(state.error!.userMessage,
                style: TextStyle(color: AppColors.error))),
      KioskReadyScreen(
        camera: state.session != null && state.session!.faceEnabled && !_qrOpen
            ? KioskCamera(
                key: const ValueKey('kiosk-camera'),
                onReady: (capture) {
                  _capture = capture;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() {});
                  });
                },
                onStatus: (status) => state.cameraStatus = status,
              )
            : Container(
                decoration: BoxDecoration(
                    color: const Color(0xFF202D39),
                    borderRadius: BorderRadius.circular(14)),
                child: const Center(
                    child: Icon(Icons.person_outline,
                        size: 160, color: Color(0xFF52667A)))),
        connected: state.session != null,
        online: state.online,
        busy: state.busy,
        faceEnabled: state.session?.faceEnabled ?? true,
        isExit: state.session?.isExit ?? false,
        qrTtl: state.session?.qrTtlSeconds ?? 30,
        onConnect: _connect,
        onFace: state.canScan && _capture != null
            ? () => state.recognize(_capture!)
            : null,
        onQr: state.canScan ? _openQr : null,
      ),
      if (state.busy)
        const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator()),
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

  Future<void> _openQr() async {
    if (_qrOpen || !ref.read(kioskControllerProvider).canScan) return;
    setState(() => _qrOpen = true);
    final token = await showDialog<String>(
        context: context, builder: (_) => const _QrDialog());
    if (!mounted) return;
    setState(() => _qrOpen = false);
    if (token != null && token.trim().isNotEmpty) {
      await ref.read(kioskControllerProvider).scanQr(token);
    }
  }
}

class _ConnectDialog extends StatefulWidget {
  const _ConnectDialog();
  @override
  State<_ConnectDialog> createState() => _ConnectDialogState();
}

class _ConnectDialogState extends State<_ConnectDialog> {
  final _id = TextEditingController(), _credential = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _id.dispose();
    _credential.dispose();
    super.dispose();
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
                        controller: _id,
                        decoration: const InputDecoration(
                            labelText: 'ID thiết bị (UUID)'),
                        validator: (value) =>
                            RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
                                    .hasMatch(value?.trim() ?? '')
                                ? null
                                : 'Nhập UUID do quản trị viên cấp'),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: _credential,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration:
                            const InputDecoration(labelText: 'Khóa thiết bị'),
                        validator: (value) => (value?.trim().length ?? 0) < 32
                            ? 'Khóa thiết bị không hợp lệ'
                            : null),
                  ],
                ))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(
                      context, (_id.text.trim(), _credential.text.trim()));
                }
              },
              child: const Text('Kết nối')),
        ],
      );
}

class _QrDialog extends StatefulWidget {
  const _QrDialog();
  @override
  State<_QrDialog> createState() => _QrDialogState();
}

class _QrDialogState extends State<_QrDialog> {
  final _text = TextEditingController();
  final _scanner = MobileScannerController();
  bool _submitted = false;
  void _submit(String? token) {
    if (_submitted || token == null || token.trim().isEmpty) return;
    _submitted = true;
    Navigator.pop(context, token.trim());
  }

  @override
  void dispose() {
    _text.dispose();
    unawaited(_scanner.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Quét mã QR cá nhân'),
        content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                    height: 240,
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: MobileScanner(
                            controller: _scanner,
                            onDetect: (capture) {
                              if (capture.barcodes.isNotEmpty) {
                                _submit(capture.barcodes.first.rawValue);
                              }
                            }))),
                const SizedBox(height: 16),
                TextField(
                    controller: _text,
                    onSubmitted: _submit,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: const InputDecoration(
                        labelText: 'Hoặc nhập mã từ đầu đọc QR')),
              ],
            ))),
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
