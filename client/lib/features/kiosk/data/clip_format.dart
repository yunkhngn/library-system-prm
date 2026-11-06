import 'dart:typed_data';

/// Video containers the server accepts for a face clip.
///
/// MP4 comes from the mobile camera; browsers record WebM (Safari records MP4).
/// The format is detected from the bytes, never assumed, so the upload is
/// always labelled with what it really is.
enum ClipFormat {
  mp4('mp4'),
  webm('webm');

  const ClipFormat(this.mimeSubtype);

  final String mimeSubtype;
  String get filename => 'capture.$mimeSubtype';
}

/// Detects the container from the leading bytes, or null if it is neither.
ClipFormat? sniffClipFormat(Uint8List bytes) {
  // MP4: size(4) + 'ftyp'.
  if (bytes.length >= 8 &&
      bytes[4] == 0x66 &&
      bytes[5] == 0x74 &&
      bytes[6] == 0x79 &&
      bytes[7] == 0x70) {
    return ClipFormat.mp4;
  }
  // WebM/Matroska: EBML magic 1A 45 DF A3.
  if (bytes.length >= 4 &&
      bytes[0] == 0x1A &&
      bytes[1] == 0x45 &&
      bytes[2] == 0xDF &&
      bytes[3] == 0xA3) {
    return ClipFormat.webm;
  }
  return null;
}
