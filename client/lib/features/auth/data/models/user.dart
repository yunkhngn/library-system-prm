enum UserRole {
  student('STUDENT', 'Sinh viên'),
  librarian('LIBRARIAN', 'Thủ thư'),
  admin('ADMIN', 'Quản trị viên');

  const UserRole(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static UserRole fromApi(String value) =>
      values.firstWhere((r) => r.apiValue == value, orElse: () => throw FormatException('Unknown role $value'));

  bool get isStaff => this == librarian || this == admin;
}

/// Backend `User` schema.
class User {
  const User({
    required this.id,
    required this.code,
    required this.email,
    required this.fullName,
    required this.role,
    required this.status,
    required this.mustChangePassword,
    required this.faceEnrolled,
    required this.version,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        code: json['code'] as String,
        email: json['email'] as String,
        fullName: json['fullName'] as String,
        role: UserRole.fromApi(json['role'] as String),
        status: json['status'] as String,
        mustChangePassword: json['mustChangePassword'] as bool,
        faceEnrolled: json['faceEnrolled'] as bool,
        version: (json['version'] as num).toInt(),
      );

  final String id;
  final String code;
  final String email;
  final String fullName;
  final UserRole role;
  final String status;
  final bool mustChangePassword;
  final bool faceEnrolled;
  final int version;

  /// Initials for avatars, e.g. "Nguyễn Thị Huyền" -> "NH".
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
