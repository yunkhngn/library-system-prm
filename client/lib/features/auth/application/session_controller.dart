import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';
import '../data/models/token_pair.dart';
import '../data/models/user.dart';

sealed class SessionState {
  const SessionState();
}

/// Startup: trying to resume from the stored refresh token.
class SessionRestoring extends SessionState {
  const SessionRestoring();
}

class SignedOut extends SessionState {
  const SignedOut({this.expired = false});

  /// True when the session ended without the user logging out (AUTH-05).
  final bool expired;
}

class Authenticated extends SessionState {
  const Authenticated(this.user);

  final User user;
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);
  TokenStorage get _tokens => ref.read(tokenStorageProvider);

  @override
  SessionState build() {
    Future.microtask(_restore);
    return const SessionRestoring();
  }

  Future<void> _restore() async {
    final ok = await refresh();
    if (!ok) state = const SignedOut();
  }

  /// Throws [ApiException] so the login screen can render the error variant.
  Future<void> login({required String identifier, required String password}) async {
    final pair = await _repository.login(identifier: identifier, password: password);
    await _apply(pair);
  }

  /// Returns false when there is no valid refresh token.
  Future<bool> refresh() async {
    final refreshToken = await _tokens.readRefreshToken();
    if (refreshToken == null) return false;
    try {
      await _apply(await _repository.refresh(refreshToken));
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) await _tokens.clear();
      return false;
    }
  }

  /// Backend rotates tokens after a password change and clears `mustChangePassword`.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final pair = await _repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    await _apply(pair);
  }

  Future<void> logout() async {
    final refreshToken = await _tokens.readRefreshToken();
    if (refreshToken != null) {
      try {
        await _repository.logout(refreshToken);
      } on ApiException {
        // Local sign-out must succeed even if the server is unreachable.
      }
    }
    await _tokens.clear();
    state = const SignedOut();
  }

  Future<void> expire() async {
    await _tokens.clear();
    state = const SignedOut(expired: true);
  }

  Future<void> _apply(TokenPair pair) async {
    await _tokens.save(accessToken: pair.accessToken, refreshToken: pair.refreshToken);
    state = Authenticated(pair.user);
  }
}
