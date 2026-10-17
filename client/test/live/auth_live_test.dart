// Runs against a real backend. Skipped unless enabled:
//   flutter test test/live --dart-define=LIVE_API=true
// Optional: --dart-define=API_BASE_URL=... --dart-define=LIVE_PASSWORD=...
@Tags(['live'])
library;

import 'package:client/core/network/api_error.dart';
import 'package:client/core/storage/token_storage.dart';
import 'package:client/features/auth/application/session_controller.dart';
import 'package:client/features/auth/data/auth_repository.dart';
import 'package:client/features/auth/data/models/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _enabled = bool.fromEnvironment('LIVE_API');
const _password = String.fromEnvironment('LIVE_PASSWORD',
    defaultValue: 'dev_secret_password_123');

class _MemoryTokenStorage extends TokenStorage {
  String? refreshToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> save(
      {required String accessToken, required String refreshToken}) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
  }
}

void main() {
  group('Auth against live backend',
      skip: _enabled ? false : 'Enable with --dart-define=LIVE_API=true', () {
    late _MemoryTokenStorage tokens;
    late ProviderContainer container;

    SessionController session() =>
        container.read(sessionControllerProvider.notifier);
    AuthRepository repository() => container.read(authRepositoryProvider);

    setUp(() async {
      tokens = _MemoryTokenStorage();
      container = ProviderContainer(
          overrides: [tokenStorageProvider.overrideWithValue(tokens)]);
      container.read(sessionControllerProvider);
      await Future<void>.delayed(Duration.zero);
    });

    tearDown(() async {
      if (tokens.refreshToken != null) await session().logout();
      container.dispose();
    });

    test('login LIB001 → Authenticated librarian', () async {
      await session().login(identifier: 'LIB001', password: _password);

      final state = container.read(sessionControllerProvider) as Authenticated;
      expect(state.user.role, UserRole.librarian);
      expect(tokens.accessToken, isNotNull);
    });

    test('identifier is trimmed and email works', () async {
      final user = (await repository()
              .login(identifier: '  LIB001 ', password: _password))
          .user;
      await session().login(identifier: user.email, password: _password);

      expect(container.read(sessionControllerProvider), isA<Authenticated>());
    });

    test('wrong password → INVALID_CREDENTIALS with Vietnamese message',
        () async {
      try {
        await session().login(identifier: 'LIB001', password: 'wrong-password');
        fail('login should have failed');
      } on ApiException catch (e) {
        expect(e.code, 'INVALID_CREDENTIALS');
        expect(e.userMessage, 'Mã tài khoản, email hoặc mật khẩu không đúng.');
      }
      expect(container.read(sessionControllerProvider), isA<SignedOut>());
    });

    test('expired access token is refreshed transparently by AuthInterceptor',
        () async {
      await session().login(identifier: 'LIB001', password: _password);
      final oldRefresh = tokens.refreshToken;
      tokens.accessToken = 'invalid-token-to-force-401';

      final me = await repository().me();

      expect(me.code, 'LIB001');
      expect(tokens.accessToken, isNot('invalid-token-to-force-401'));
      expect(tokens.refreshToken, isNot(oldRefresh),
          reason: 'backend rotates refresh tokens');
    });

    test('wrong current password → CURRENT_PASSWORD_INVALID, session kept',
        () async {
      await session().login(identifier: 'LIB001', password: _password);

      await expectLater(
        session().changePassword(
            currentPassword: 'wrong-password',
            newPassword: 'DevOnly!2026Change'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'CURRENT_PASSWORD_INVALID')),
      );
      expect(container.read(sessionControllerProvider), isA<Authenticated>());
    });

    test('logout revokes the refresh token on the server', () async {
      await session().login(identifier: 'LIB001', password: _password);
      final revoked = tokens.refreshToken!;

      await session().logout();

      expect(container.read(sessionControllerProvider), isA<SignedOut>());
      await expectLater(
          repository().refresh(revoked), throwsA(isA<ApiException>()));
    });

    for (final (code, role) in [
      ('AD001', UserRole.admin),
      ('SV001', UserRole.student)
    ]) {
      test('login $code → ${role.label}', () async {
        await session().login(identifier: code, password: _password);
        expect(
            (container.read(sessionControllerProvider) as Authenticated)
                .user
                .role,
            role);
      });
    }
  });
}
