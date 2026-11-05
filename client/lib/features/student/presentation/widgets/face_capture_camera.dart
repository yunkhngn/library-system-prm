import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../data/capture_cleanup.dart';

typedef FaceCameraBuilder = Widget Function(BuildContext context,
    Future<void> Function(Uint8List) onCaptured, int maxBytes, bool enabled);
final faceCameraBuilderProvider = Provider<FaceCameraBuilder>((ref) =>
    (context, onCaptured, maxBytes, enabled) => FaceCaptureCamera(
        onCaptured: onCaptured, maxBytes: maxBytes, enabled: enabled));

class FaceCaptureCamera extends StatefulWidget {
  const FaceCaptureCamera(
      {super.key,
      required this.onCaptured,
      required this.maxBytes,
      required this.enabled});
  final Future<void> Function(Uint8List) onCaptured;
  final int maxBytes;
  final bool enabled;
  @override
  State<FaceCaptureCamera> createState() => _FaceCaptureCameraState();
}

class _FaceCaptureCameraState extends State<FaceCaptureCamera>
    with WidgetsBindingObserver {
  CameraController? _camera;
  String? _error;
  bool _starting = true, _capturing = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  Future<void> _start() async {
    final generation = ++_generation;
    final old = _camera;
    _camera = null;
    if (mounted) {
      setState(() {
        _starting = true;
        _error = null;
      });
    }
    try {
      await old?.dispose();
      final cameras = await availableCameras();
      if (!mounted || generation != _generation) return;
      if (cameras.isEmpty) throw CameraException('NoCamera', '');
      final camera = CameraController(
          cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
              orElse: () => cameras.first),
          ResolutionPreset.medium,
          enableAudio: false);
      _camera = camera;
      await camera.initialize();
      if (!mounted || generation != _generation) return;
      setState(() => _starting = false);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      final failed = _camera;
      _camera = null;
      unawaited(failed?.dispose());
      setState(() {
        _starting = false;
        _error = error is CameraException &&
                error.code.startsWith('CameraAccess')
            ? 'Chưa được cấp quyền camera. Hãy bật quyền trong cài đặt hoặc chọn ảnh từ thiết bị.'
            : 'Không mở được camera. Bạn có thể chọn ảnh từ thiết bị.';
      });
    }
  }

  void _stop() {
    _generation++;
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
      if (mounted) setState(() => _starting = true);
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null ||
        _capturing ||
        !widget.enabled ||
        !camera.value.isInitialized) {
      return;
    }
    final generation = _generation;
    setState(() {
      _capturing = true;
      _error = null;
    });
    XFile? file;
    try {
      file = await camera.takePicture();
      if (await file.length() > widget.maxBytes) {
        throw const FormatException(
            'Ảnh vượt giới hạn dung lượng. Hãy chọn ảnh nhỏ hơn.');
      }
      final bytes = await file.readAsBytes();
      if (!mounted || generation != _generation) return;
      await widget.onCaptured(bytes);
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error is FormatException
            ? error.message.toString()
            : 'Không chụp được ảnh. Vui lòng thử lại hoặc chọn ảnh từ thiết bị.');
      }
    } finally {
      if (file != null) await deleteCameraCapture(file.path);
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
          height: 180,
          child: ClipRRect(
              borderRadius: AppRadius.cardBorder,
              child: ColoredBox(
                  color: AppColors.textPrimary,
                  child: Stack(alignment: Alignment.center, children: [
                    if (camera != null &&
                        camera.value.isInitialized &&
                        !_starting)
                      Center(
                          child: AspectRatio(
                              aspectRatio: camera.value.aspectRatio,
                              child: CameraPreview(camera))),
                    if (_starting)
                      CircularProgressIndicator(color: AppColors.surface),
                    if (!_starting && camera != null)
                      IgnorePointer(
                          child: Container(
                              width: 126,
                              height: 140,
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(62),
                                  border: Border.all(
                                      color: AppColors.surface, width: 2)))),
                    if (!_starting && camera == null)
                      Icon(Icons.no_photography_outlined,
                          size: 48, color: AppColors.surface),
                  ])))),
      const SizedBox(height: AppSpacing.sm),
      Text('Đưa khuôn mặt vào giữa khung',
          style: AppTypography.label, textAlign: TextAlign.center),
      if (_error != null) ...[
        const SizedBox(height: AppSpacing.sm),
        Text(_error!, style: AppTypography.caption, textAlign: TextAlign.center)
      ],
      const SizedBox(height: AppSpacing.sm),
      if (camera != null && !_starting)
        AppButton(
            label: 'Chụp ảnh',
            icon: Icons.camera_alt_outlined,
            loading: _capturing,
            onPressed: widget.enabled ? _capture : null)
      else if (!_starting)
        AppButton(
            label: 'Thử mở lại camera',
            variant: AppButtonVariant.secondary,
            onPressed: widget.enabled ? _start : null),
    ]);
  }
}
