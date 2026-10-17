import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'auth_api.dart';
import 'models/token_pair.dart';
import 'models/user.dart';

/// Authentication data contract used by the application layer. Throws
/// `ApiException` on failure. Tests override [authRepositoryProvider] with a fake.
abstract interface class AuthRepository {
  Future<TokenPair> login({required String identifier, required String password});
  Future<TokenPair> refresh(String refreshToken);
  Future<void> logout(String refreshToken);
  Future<User> me();
  Future<TokenPair> changePassword({required String currentPassword, required String newPassword});
}

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthApi(ref.read(dioProvider)));
