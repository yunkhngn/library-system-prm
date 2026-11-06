import 'dart:typed_data';

import 'package:client/features/kiosk/data/clip_format.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List mp4() => Uint8List.fromList(
    [0, 0, 0, 0x20, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6f, 0x6d]); // ....ftypisom
Uint8List webm() => Uint8List.fromList(
    [0x1A, 0x45, 0xDF, 0xA3, 0x9F, 0x42, 0x86, 0x81, 0x01, 0x42, 0xF7, 0x81]); // EBML header

void main() {
  group('sniffClipFormat', () {
    test('recognises an MP4 container', () {
      expect(sniffClipFormat(mp4()), ClipFormat.mp4);
    });

    test('recognises a WebM (Matroska/EBML) container', () {
      expect(sniffClipFormat(webm()), ClipFormat.webm);
    });

    test('rejects anything else', () {
      expect(sniffClipFormat(Uint8List.fromList(List.filled(12, 5))), isNull);
      expect(sniffClipFormat(Uint8List(0)), isNull);
      expect(sniffClipFormat(Uint8List.fromList([0x1A, 0x45, 0xDF])), isNull);
    });
  });

  test('upload metadata matches the detected container', () {
    expect(ClipFormat.mp4.filename, 'capture.mp4');
    expect(ClipFormat.mp4.mimeSubtype, 'mp4');
    expect(ClipFormat.webm.filename, 'capture.webm');
    expect(ClipFormat.webm.mimeSubtype, 'webm');
  });
}
