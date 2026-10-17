/// Backend `Actor` schema: a minimal reference to a user shown in the UI.
class Actor {
  const Actor({required this.id, required this.code, required this.fullName});

  factory Actor.fromJson(Map<String, dynamic> json) => Actor(
        id: json['id'] as String,
        code: json['code'] as String,
        fullName: json['fullName'] as String,
      );

  final String id;
  final String code;
  final String fullName;

  /// Same rule as `User.initials`: "Nguyễn Thị Huyền" -> "NH".
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
