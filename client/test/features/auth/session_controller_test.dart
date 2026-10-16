import 'package:client/core/network/api_error.dart';
import 'package:client/core/storage/token_storage.dart';
import 'package:client/features/auth/application/session_controller.dart';
import 'package:client/features/auth/data/auth_repository.dart';
import 'package:client/features/auth/data/models/token_pair.dart';
import 'package:client/features/auth/data/models/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

User _user({bool mustChangePassword = false}) => User.fromJson({
      'id': '14867700-9090-4000-8000-000000000001',
      'code': 'LIB001',
      'email': 'lib001@example.edu.vn',
      'fullName': 'Nguyễn Thị Huyền',
      'role': 'LIBRARIAN',
      'status': 'ACTIVE',
      'mustChangePassword': mustChangePassword,
      'faceEnrolled': false,
      'version': 0,
    });

TokenPair _pair(User user, {String suffix = '1'}) => TokenPair(
      accessToken: 'access-$suffix',
      refreshToken: 'refresh-$suffix',
      expiresIn: const Duration(minutes: 15),
      user: user,
    );

class _MemoryTokenStorage extends TokenStorage {
  _MemoryTokenStorage([this.refreshToken]);

  String? refreshToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> save({required String accessToken, required String refreshToken}) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
  }
}

class _FakeAuthRepository implements AuthRepository {
  TokenPair? loginResult;
  TokenPair? refreshResult;
  TokenPair? changePasswordResult;
  ApiException? error;
  final logoutCalls = <String>[];

  Future<T> _respond<T>(T? value) async {
    if (error != null) throw error!;
    return value as T;
  }

  @override
  Future<TokenPair> login({required String identifier, required String password}) =>
      _respond(loginResult);

  @override
  Future<TokenPair> refresh(String refreshToken) => _respond(refreshResult);

  @override
  Future<void> logout(String refreshToken) async => logoutCalls.add(refreshToken);

  @override
  Future<User> me() => _respond(loginResult?.user);

  @override
  Future<TokenPair> changePassword({required String currentPassword, required String newPassword}) =>
      _respond(changePasswordResult);
}

void main() {
  late _FakeAuthRepository repository;
  late _MemoryTokenStorage tokens;

  ProviderContainer createContainer() {
    final container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      tokenStorageProvider.overrideWithValue(tokens),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  Future<SessionState> settle(ProviderContainer container) async {
    container.read(sessionControllerProvider);
    await Future<void>.delayed(Duration.zero);
    return container.read(sessionControllerProvider);
  }

  setUp(() {
    repository = _FakeAuthRepository();
    tokens = _MemoryTokenStorage();
  });

  test('without a stored refresh token the session becomes SignedOut', () async {
    final state = await settle(createContainer());
    expect(state, isA<SignedOut>());
  });

  test('a valid stored refresh token restores the session', () async {
    tokens = _MemoryTokenStorage('refresh-old');
    repository.refreshResult = _pair(_user(), suffix: 'new');

    final state = await settle(createContainer());

    expect(state, isA<Authenticated>());
    expect(tokens.refreshToken, 'refresh-new');
  });

  test('login stores tokens and exposes mustChangePassword', () async {
    repository.loginResult = _pair(_user(mustChangePassword: true));
    final container = createContainer();
    await settle(container);

    await container
        .read(sessionControllerProvider.notifier)
        .login(identifier: 'LIB001', password: 'secret');

    final state = container.read(sessionControllerProvider) as Authenticated;
    expect(state.user.mustChangePassword, isTrue);
    expect(tokens.accessToken, 'access-1');
  });

  test('changing the password clears mustChangePassword', () async {
    repository.loginResult = _pair(_user(mustChangePassword: true));
    repository.changePasswordResult = _pair(_user(), suffix: '2');
    final container = createContainer();
    await settle(container);
    final controller = container.read(sessionControllerProvider.notifier);

    await controller.login(identifier: 'LIB001', password: 'secret');
    await controller.changePassword(currentPassword: 'secret', newPassword: 'DevOnly!2026Change');

    final state = container.read(sessionControllerProvider) as Authenticated;
    expect(state.user.mustChangePassword, isFalse);
    expect(tokens.refreshToken, 'refresh-2');
  });

  test('failed login rethrows ApiException and stays signed out', () async {
    repository.error = const ApiException(code: 'INVALID_CREDENTIALS', statusCode: 401);
    final container = createContainer();
    await settle(container);

    await expectLater(
      container.read(sessionControllerProvider.notifier).login(identifier: 'x', password: 'y'),
      throwsA(isA<ApiException>()),
    );
    expect(container.read(sessionControllerProvider), isA<SignedOut>());
  });

  test('logout revokes the refresh token and signs out', () async {
    repository.loginResult = _pair(_user());
    final container = createContainer();
    await settle(container);
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.login(identifier: 'LIB001', password: 'secret');

    await controller.logout();

    expect(repository.logoutCalls, ['refresh-1']);
    expect(tokens.refreshToken, isNull);
    expect(container.read(sessionControllerProvider), isA<SignedOut>());
  });

  test('expire marks the session as expired for AUTH-05', () async {
    repository.loginResult = _pair(_user());
    final container = createContainer();
    await settle(container);
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.login(identifier: 'LIB001', password: 'secret');

    await controller.expire();

    final state = container.read(sessionControllerProvider) as SignedOut;
    expect(state.expired, isTrue);
  });
}
