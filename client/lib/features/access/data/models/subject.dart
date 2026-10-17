/// Backend `Subject.kind`: USER is a student account, VISITOR is a guest.
enum SubjectKind {
  user('USER', 'Sinh viên'),
  visitor('VISITOR', 'Khách ngoài');

  const SubjectKind(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static SubjectKind parse(String? value) =>
      value?.toUpperCase() == 'VISITOR' ? visitor : user;
}

class Subject {
  const Subject({
    required this.id,
    required this.kind,
    required this.code,
    required this.fullName,
  });

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
        id: json['id'] as String,
        kind: SubjectKind.parse(json['kind'] as String?),
        code: json['code'] as String,
        fullName: json['fullName'] as String,
      );

  final String id;
  final SubjectKind kind;
  final String code;
  final String fullName;

  bool get isVisitor => kind == SubjectKind.visitor;
}

enum AccessMethod {
  face('FACE', 'Khuôn mặt'),
  qr('QR', 'Mã QR'),
  manual('MANUAL', 'Thủ công');

  const AccessMethod(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static AccessMethod? tryParse(String? value) {
    if (value == null) return null;
    final upper = value.toUpperCase();
    for (final m in values) {
      if (m.apiValue == upper) return m;
    }
    return null;
  }
}

enum AccessAction {
  checkIn('CHECK_IN', 'Ghi nhận vào'),
  checkOut('CHECK_OUT', 'Ghi nhận ra');

  const AccessAction(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static AccessAction parse(String? value) =>
      value?.toUpperCase() == 'CHECK_OUT' ? checkOut : checkIn;
}

class KioskSummary {
  const KioskSummary({required this.id, required this.code, required this.name});

  factory KioskSummary.fromJson(Map<String, dynamic> json) => KioskSummary(
        id: json['id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
      );

  final String id;
  final String code;
  final String name;
}
