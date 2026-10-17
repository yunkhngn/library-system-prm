import 'dart:convert';

/// One rule shown in the password checklist.
enum PasswordRule {
  length('Từ 12 đến 64 ký tự'),
  uppercase('Có chữ in hoa (A–Z)'),
  lowercase('Có chữ thường (a–z)'),
  digit('Có chữ số (0–9)'),
  special('Có ký tự đặc biệt (!@#\$…)');

  const PasswordRule(this.label);
  final String label;
}

enum PasswordStrength {
  empty(''),
  weak('Yếu'),
  fair('Trung bình'),
  good('Mạnh'),
  strong('Rất mạnh');

  const PasswordStrength(this.label);
  final String label;

  /// Number of filled segments in the 4-segment meter.
  int get level => index;
}

/// Backend `ChangePasswordRequest.newPassword` only enforces 12–64 characters;
/// the 72 UTF-8 byte cap is the BCrypt limit. Character-class rules are a
/// client-side requirement. Passwords are never trimmed.
abstract final class PasswordPolicy {
  static const minLength = 12;
  static const maxLength = 64;
  static const maxBytes = 72;

  static const byteNote = 'Ký tự có dấu có thể làm mật khẩu vượt giới hạn 72 byte.';
  static const byteTooltip =
      'Mật khẩu có nhiều ký tự có dấu có thể chiếm nhiều dung lượng hơn. '
      'Tổng độ dài tối đa là 72 byte UTF-8.';

  static const lengthMessage = 'Mật khẩu dài từ 12 đến 64 ký tự.';
  static const bytesMessage =
      'Mật khẩu quá dài khi dùng nhiều ký tự có dấu. Hãy rút ngắn mật khẩu.';
  static const sameAsCurrentMessage = 'Mật khẩu mới phải khác mật khẩu hiện tại.';

  static final _upper = RegExp(r'\p{Lu}', unicode: true);
  static final _lower = RegExp(r'\p{Ll}', unicode: true);
  static final _digit = RegExp(r'\p{Nd}', unicode: true);
  static final _special = RegExp(r'[^\p{L}\p{M}\p{N}\s]', unicode: true);

  static const _commonFragments = [
    'password', 'matkhau', 'qwerty', 'admin', 'library', 'thuvien', 'abc', '123',
  ];

  static Set<PasswordRule> satisfiedRules(String value) {
    final length = value.runes.length;
    return {
      if (length >= minLength && length <= maxLength) PasswordRule.length,
      if (_upper.hasMatch(value)) PasswordRule.uppercase,
      if (_lower.hasMatch(value)) PasswordRule.lowercase,
      if (_digit.hasMatch(value)) PasswordRule.digit,
      if (_special.hasMatch(value)) PasswordRule.special,
    };
  }

  static String? validateNew(String? value, {String? current}) {
    final v = value ?? '';
    final satisfied = satisfiedRules(v);
    if (!satisfied.contains(PasswordRule.length)) return lengthMessage;
    if (utf8.encode(v).length > maxBytes) return bytesMessage;
    final missing = PasswordRule.values.where((r) => !satisfied.contains(r)).toList();
    if (missing.isNotEmpty) {
      return 'Mật khẩu còn thiếu: ${missing.map((r) => _missingLabel(r)).join(', ')}.';
    }
    if (current != null && current.isNotEmpty && v == current) {
      return sameAsCurrentMessage;
    }
    return null;
  }

  static String? validateConfirm(String? value, String newPassword) =>
      value == newPassword ? null : 'Mật khẩu xác nhận không khớp.';

  /// Anything that fails a required rule is [PasswordStrength.weak]; valid
  /// passwords are graded by length and penalised for predictable patterns.
  static PasswordStrength strengthOf(String value) {
    if (value.isEmpty) return PasswordStrength.empty;
    if (satisfiedRules(value).length < PasswordRule.values.length) {
      return PasswordStrength.weak;
    }

    final length = value.runes.length;
    var score = 0;
    if (length >= 14) score++;
    if (length >= 18) score++;
    if (_special.allMatches(value).length >= 2) score++;
    if (_hasPredictablePattern(value)) score -= 2;

    if (score <= 0) return PasswordStrength.fair;
    if (score <= 2) return PasswordStrength.good;
    return PasswordStrength.strong;
  }

  static bool _hasPredictablePattern(String value) {
    final lower = value.toLowerCase();
    if (_commonFragments.any(lower.contains)) return true;
    if (RegExp(r'(.)\1\1').hasMatch(value)) return true;
    final units = lower.codeUnits;
    for (var i = 0; i + 3 < units.length; i++) {
      final step = units[i + 1] - units[i];
      if ((step == 1 || step == -1) &&
          units[i + 2] - units[i + 1] == step &&
          units[i + 3] - units[i + 2] == step) {
        return true;
      }
    }
    return false;
  }

  static String _missingLabel(PasswordRule rule) => switch (rule) {
        PasswordRule.length => 'độ dài 12–64 ký tự',
        PasswordRule.uppercase => 'chữ in hoa',
        PasswordRule.lowercase => 'chữ thường',
        PasswordRule.digit => 'chữ số',
        PasswordRule.special => 'ký tự đặc biệt',
      };
}
