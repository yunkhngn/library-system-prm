import 'package:client/features/auth/application/password_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PasswordPolicy.validateNew', () {
    test('rejects fewer than 12 characters', () {
      expect(PasswordPolicy.validateNew('Short!2026'), PasswordPolicy.lengthMessage);
    });

    test('accepts 12 characters with every character class', () {
      expect(PasswordPolicy.validateNew('DevOnly!2026'), isNull);
    });

    test('rejects passwords over 72 UTF-8 bytes even when under 64 characters', () {
      // 'ữ' is 3 bytes in UTF-8: 4 + 23 * 3 = 73 bytes in 27 characters.
      expect(PasswordPolicy.validateNew('Aa1!${'ữ' * 23}'), PasswordPolicy.bytesMessage);
    });

    test('lists every missing character class', () {
      final message = PasswordPolicy.validateNew('devonlypassword');
      expect(message, contains('chữ in hoa'));
      expect(message, contains('chữ số'));
      expect(message, contains('ký tự đặc biệt'));
      expect(message, isNot(contains('chữ thường')));
    });

    test('counts Vietnamese letters as upper and lower case', () {
      expect(PasswordPolicy.validateNew('ĐăngNhập#2026'), isNull);
    });

    test('does not count whitespace as a special character', () {
      expect(PasswordPolicy.validateNew('Dev Only 2026'), contains('ký tự đặc biệt'));
    });

    test('rejects a new password equal to the current one', () {
      expect(
        PasswordPolicy.validateNew('DevOnly!2026', current: 'DevOnly!2026'),
        PasswordPolicy.sameAsCurrentMessage,
      );
    });
  });

  group('PasswordPolicy.strengthOf', () {
    test('is empty for an empty value', () {
      expect(PasswordPolicy.strengthOf(''), PasswordStrength.empty);
    });

    test('is weak while any rule is unmet', () {
      expect(PasswordPolicy.strengthOf('averylongpasswordwithoutrules'), PasswordStrength.weak);
      expect(PasswordPolicy.strengthOf('Ab1!'), PasswordStrength.weak);
    });

    test('is fair for a minimal valid password', () {
      expect(PasswordPolicy.strengthOf('DevOnly!2026'), PasswordStrength.fair);
    });

    test('is good for a longer valid password', () {
      expect(PasswordPolicy.strengthOf('Kiosk!Mor9ning'), PasswordStrength.good);
    });

    test('is strong for long and varied passwords', () {
      expect(PasswordPolicy.strengthOf('Thu#Vien!Sach9Cu7Mo'), PasswordStrength.strong);
    });

    test('penalises predictable patterns', () {
      expect(PasswordPolicy.strengthOf('Password!12345678'), PasswordStrength.fair);
      expect(PasswordPolicy.strengthOf('Aaaa!Bxyz9Kq7Mw'), PasswordStrength.fair);
    });
  });

  test('validateConfirm detects mismatch', () {
    expect(PasswordPolicy.validateConfirm('a', 'b'), isNotNull);
    expect(PasswordPolicy.validateConfirm('a', 'a'), isNull);
  });
}
