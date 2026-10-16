import 'user.dart';

/// Backend `TokenPair` schema, returned by login, refresh and password change.
class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  factory TokenPair.fromJson(Map<String, dynamic> json) => TokenPair(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        expiresIn: Duration(seconds: (json['expiresIn'] as num).toInt()),
        user: User.fromJson(json['user'] as Map<String, dynamic>),
      );

  final String accessToken;
  final String refreshToken;
  final Duration expiresIn;
  final User user;
}
