import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Always-on camera pane for QR-only kiosks. Detections are ignored while
/// [enabled] is false (a scan is in flight or a result is on screen), and the
/// same code is not resubmitted while it is still held in front of the lens.
class KioskQrScanner extends StatefulWidget {
  const KioskQrScanner({
    super.key,
    required this.enabled,
    required this.onToken,
    required this.onStatus,
  });

  final bool enabled;
  final ValueChanged<String> onToken;
  final ValueChanged<String> onStatus;

  @override
  State<KioskQrScanner> createState() => _KioskQrScannerState();
}

class _KioskQrScannerState extends State<KioskQrScanner> {
  static const _repeatWindow = Duration(seconds: 15);
  final _controller = MobileScannerController();
  String? _lastToken;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    widget.onStatus('OK');
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _detect(BarcodeCapture capture) {
    if (!widget.enabled || capture.barcodes.isEmpty) return;
    final token = capture.barcodes.first.rawValue?.trim();
    if (token == null || token.isEmpty) return;
    final now = DateTime.now();
    if (token == _lastToken && now.difference(_lastAt) < _repeatWindow) return;
    _lastToken = token;
    _lastAt = now;
    widget.onToken(token);
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ColoredBox(
          color: const Color(0xFF1B2733),
          child: Stack(fit: StackFit.expand, children: [
            MobileScanner(
              controller: _controller,
              onDetect: _detect,
              errorBuilder: (context, _) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => widget.onStatus('ERROR'));
                return const KioskScannerError();
              },
            ),
            IgnorePointer(
              child: Center(
                child: FractionallySizedBox(
                  heightFactor: .62,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CustomPaint(painter: KioskScanFrame()),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    widget.enabled
                        ? 'Đưa mã QR vào giữa khung'
                        : 'Đang xử lý mã vừa quét…',
                    style: AppTypography.bodyL.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
}

class KioskScannerError extends StatelessWidget {
  const KioskScannerError({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.videocam_off_outlined,
                size: 44, color: Colors.white54),
            const SizedBox(height: 10),
            Text(
                'Không mở được camera. Hãy cấp quyền camera cho trang này hoặc nhập mã thủ công.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyM.copyWith(color: Colors.white70)),
          ]),
        ),
      );
}

class KioskScanFrame extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const arm = 32.0;
    final w = size.width, h = size.height;
    for (final (corner, dx, dy) in [
      (Offset.zero, arm, arm),
      (Offset(w, 0), -arm, arm),
      (Offset(0, h), arm, -arm),
      (Offset(w, h), -arm, -arm),
    ]) {
      canvas.drawLine(corner, corner.translate(dx, 0), paint);
      canvas.drawLine(corner, corner.translate(0, dy), paint);
    }
  }

  @override
  bool shouldRepaint(KioskScanFrame oldDelegate) => false;
}
