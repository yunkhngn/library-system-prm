class StudentLookup {
  const StudentLookup({
    required this.id,
    required this.code,
    required this.fullName,
    required this.status,
    required this.isInside,
    this.currentSessionId,
    this.checkInTime,
  });

  factory StudentLookup.fromJson(Map<String, dynamic> json) => StudentLookup(
        id: json['id'] as String,
        code: json['code'] as String,
        fullName: json['fullName'] as String,
        status: json['status'] as String,
        isInside: json['isInside'] as bool? ?? false,
        currentSessionId: json['currentSessionId'] as String?,
        checkInTime:
            json['checkInTime'] == null ? null : DateTime.parse(json['checkInTime'] as String),
      );

  final String id;
  final String code;
  final String fullName;
  final String status;
  final bool isInside;
  final String? currentSessionId;
  final DateTime? checkInTime;

  bool get isLocked => status.toUpperCase() == 'LOCKED';
  bool get isActive => status.toUpperCase() == 'ACTIVE';
}
