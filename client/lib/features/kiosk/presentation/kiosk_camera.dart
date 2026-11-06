import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_error.dart';
import '../../student/data/capture_cleanup.dart';
import '../application/kiosk_controller.dart';
import '../data/kiosk_repository.dart';

class KioskCamera extends StatefulWidget {
  const KioskCamera({super.key, required this.onReady, required this.onStatus});
  final ValueChanged<KioskCapture?> onReady;
  final ValueChanged<String> onStatus;
  @override
  State<KioskCamera> createState() => _KioskCameraState();
}

class _KioskCameraState extends State<KioskCamera> with WidgetsBindingObserver {
  CameraController? _camera;
  String? _error;
  String _instruction = '';
  int _generation = 0;
  bool _recording = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  Future<void> _start() async {
    final generation = ++_generation;
    try {
      final devices = await availableCameras();
      if (!mounted || generation != _generation) return;
      if (devices.isEmpty) throw const ApiException(code: 'CAMERA_UNAVAILABLE');
      final camera = CameraController(
          devices.firstWhere(
              (item) => item.lensDirection == CameraLensDirection.front,
              orElse: () => devices.first),
          ResolutionPreset.medium,
          enableAudio: false);
      _camera = camera;
      await camera.initialize();
      if (!mounted || generation != _generation) return;
      setState(() => _error = null);
      widget.onReady(_capture);
      widget.onStatus('OK');
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _error =
          'Không mở được camera. Hãy cấp quyền camera hoặc sử dụng mã QR.');
      widget.onStatus('ERROR');
    }
  }

  Future<Uint8List> _capture(KioskChallenge challenge) async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _recording) {
      throw const ApiException(code: 'CAMERA_UNAVAILABLE');
    }
    final generation = _generation;
    _recording = true;
    try {
      await camera.startVideoRecording();
      final steps = challenge.instructions.isEmpty
          ? ['Nhìn thẳng vào camera']
          : challenge.instructions;
      for (final step in steps) {
        if (!mounted || generation != _generation) {
          throw const ApiException(code: 'CAPTURE_CANCELLED');
        }
        setState(() => _instruction = step);
        await Future<void>.delayed(Duration(
            milliseconds: challenge.duration.inMilliseconds ~/ steps.length));
      }
      if (!mounted || generation != _generation) {
        throw const ApiException(code: 'CAPTURE_CANCELLED');
      }
      final video = await camera.stopVideoRecording();
      try {
        if (await video.length() > challenge.maxBytes) {
          throw const ApiException(code: 'PAYLOAD_TOO_LARGE');
        }
        return await video.readAsBytes();
      } finally {
        await deleteCameraCapture(video.path);
      }
    } on CameraException {
      throw const ApiException(code: 'CAMERA_UNAVAILABLE');
    } finally {
      _recording = false;
      if (mounted && generation == _generation) {
        setState(() => _instruction = '');
      }
    }
  }

  void _stop() {
    _generation++;
    widget.onReady(null);
    final camera = _camera;
    _camera = null;
    unawaited(camera?.dispose());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else {
      _stop();
      widget.onStatus('UNAVAILABLE');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ColoredBox(
          color: const Color(0xFF1B2733),
          child: Stack(fit: StackFit.expand, children: [
            if (_camera?.value.isInitialized == true)
              Center(
                  child: AspectRatio(
                      aspectRatio: _camera!.value.aspectRatio,
                      child: CameraPreview(_camera!)))
            else
              Center(
                  child: Container(
                      width: 180,
                      height: 240,
                      decoration: const BoxDecoration(
                          color: Color(0xFF394B5D),
                          borderRadius:
                              BorderRadius.all(Radius.elliptical(100, 120))))),
            Center(
                child: FractionallySizedBox(
                    widthFactor: .48,
                    heightFactor: .68,
                    child: CustomPaint(painter: _FaceFrame()))),
            if (_error != null || _instruction.isNotEmpty)
              Positioned(
                  left: 16,
                  right: 16,
                  bottom: 20,
                  child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .7),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(_error ?? _instruction,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16)))),
          ]),
        ),
      );
}

class _FaceFrame extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final point in [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height)
    ]) {
      final dx = point.dx == 0 ? 28.0 : -28.0;
      final dy = point.dy == 0 ? 28.0 : -28.0;
      canvas.drawLine(point, point.translate(dx, 0), paint);
      canvas.drawLine(point, point.translate(0, dy), paint);
    }
  }

  @override
  bool shouldRepaint(_FaceFrame oldDelegate) => false;
}
