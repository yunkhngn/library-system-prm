import 'package:client/features/auth/application/password_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PasswordPolicy.validateNew', () {
    test('rejects fewer than 12 characters', () {
      expect(PasswordPolicy.validateNew('Short!2026'), isNotNull);
    });

    test('accepts 12 ASCII characters', () {
      expect(PasswordPolicy.validateNew('DevOnly!2026'), isNull);
    });

    test('rejects passwords over 72 UTF-8 bytes even when under 64 characters', () {
      // 'ữ' is 3 bytes in UTF-8: 25 chars -> 75 bytes.
      expect(PasswordPolicy.validateNew('ữ' * 25), isNotNull);
    });

    test('rejects a new password equal to the current one', () {
      expect(PasswordPolicy.validateNew('DevOnly!2026', current: 'DevOnly!2026'), isNotNull);
    });
  });

  test('validateConfirm detects mismatch', () {
    expect(PasswordPolicy.validateConfirm('a', 'b'), isNotNull);
    expect(PasswordPolicy.validateConfirm('a', 'a'), isNull);
  });
}
