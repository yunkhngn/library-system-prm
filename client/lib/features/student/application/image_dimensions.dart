import 'dart:typed_data';

/// Reads dimensions without decoding pixels, so the pixel limit can be checked
/// before asking the image codec to allocate memory for the image.
({int width, int height}) imageDimensions(Uint8List bytes) {
  if (bytes.length >= 24 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a &&
      _uint32(bytes, 8) == 13 &&
      bytes[12] == 0x49 &&
      bytes[13] == 0x48 &&
      bytes[14] == 0x44 &&
      bytes[15] == 0x52) {
    return _dimensions(_uint32(bytes, 16), _uint32(bytes, 20));
  }

  if (bytes.length >= 4 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    var offset = 2;
    while (offset + 4 <= bytes.length) {
      if (bytes[offset] != 0xff) break;
      while (offset < bytes.length && bytes[offset] == 0xff) {
        offset++;
      }
      if (offset >= bytes.length) break;
      final marker = bytes[offset++];
      if (marker == 0xd9 || marker == 0xda) break;
      if (marker == 0x01 || (marker >= 0xd0 && marker <= 0xd7)) continue;
      if (offset + 2 > bytes.length) break;
      final length = _uint16(bytes, offset);
      if (length < 2 || offset + length > bytes.length) break;
      if (_isStartOfFrame(marker)) {
        if (length < 7) break;
        return _dimensions(
            _uint16(bytes, offset + 5), _uint16(bytes, offset + 3));
      }
      offset += length;
    }
  }
  throw const FormatException('Ảnh không hợp lệ hoặc không đọc được.');
}

({int width, int height}) _dimensions(int width, int height) {
  if (width == 0 || height == 0) {
    throw const FormatException('Ảnh không hợp lệ hoặc không đọc được.');
  }
  return (width: width, height: height);
}

bool _isStartOfFrame(int marker) =>
    (marker >= 0xc0 && marker <= 0xc3) ||
    (marker >= 0xc5 && marker <= 0xc7) ||
    (marker >= 0xc9 && marker <= 0xcb) ||
    (marker >= 0xcd && marker <= 0xcf);

int _uint16(Uint8List bytes, int offset) =>
    (bytes[offset] << 8) | bytes[offset + 1];

int _uint32(Uint8List bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];
