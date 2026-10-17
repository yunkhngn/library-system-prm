import '../../../../shared/models/actor.dart';

class Visitor {
  const Visitor({
    required this.id,
    required this.referenceCode,
    required this.fullName,
    required this.createdBy,
    required this.createdAt,
  });

  factory Visitor.fromJson(Map<String, dynamic> json) => Visitor(
        id: json['id'] as String,
        referenceCode: json['referenceCode'] as String,
        fullName: json['fullName'] as String,
        createdBy:
            json['createdBy'] == null ? null : Actor.fromJson(json['createdBy'] as Map<String, dynamic>),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;
  final String referenceCode;
  final String fullName;
  final Actor? createdBy;
  final DateTime createdAt;
}
