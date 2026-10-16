import 'dart:convert';

/// Mirrors backend `ChangePasswordRequest.newPassword`: 12–64 characters and
/// at most 72 UTF-8 bytes (BCrypt limit). Passwords are never trimmed.
abstract final class PasswordPolicy {
  static const minLength = 12;
  static const maxLength = 64;
  static const maxBytes = 72;

  static const requirement = 'Mật khẩu dài từ 12 đến 64 ký tự.';
  static const byteTooltip =
      'Mật khẩu có nhiều ký tự có dấu có thể chiếm nhiều dung lượng hơn. '
      'Tổng độ dài tối đa là 72 byte UTF-8.';

  static String? validateNew(String? value, {String? current}) {
    final v = value ?? '';
    final length = v.runes.length;
    if (length < minLength || length > maxLength) return requirement;
    if (utf8.encode(v).length > maxBytes) {
      return 'Mật khẩu quá dài khi dùng nhiều ký tự có dấu. Hãy rút ngắn mật khẩu.';
    }
    if (current != null && current.isNotEmpty && v == current) {
      return 'Mật khẩu mới phải khác mật khẩu hiện tại.';
    }
    return null;
  }

  static String? validateConfirm(String? value, String newPassword) =>
      value == newPassword ? null : 'Mật khẩu xác nhận không khớp.';
}
