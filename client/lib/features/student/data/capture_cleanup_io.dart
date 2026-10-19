import 'dart:io';

// Only called for files just created by CameraController.takePicture, never selected files.
Future<void> deleteCameraCapture(String path) async {
  try {
    await File(path).delete();
  } on FileSystemException {/* OS temp cleanup can retry later. */}
}
