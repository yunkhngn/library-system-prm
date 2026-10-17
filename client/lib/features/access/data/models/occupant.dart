import 'subject.dart';

class Occupant {
  const Occupant({
    required this.sessionId,
    required this.subject,
    required this.checkInTime,
    required this.duration,
    required this.checkInMethod,
  });

  factory Occupant.fromJson(Map<String, dynamic> json) => Occupant(
        sessionId: json['sessionId'] as String,
        subject: Subject.fromJson(json['subject'] as Map<String, dynamic>),
        checkInTime: DateTime.parse(json['checkInTime'] as String),
        duration: Duration(seconds: (json['durationSeconds'] as num).toInt()),
        checkInMethod: AccessMethod.tryParse(json['checkInMethod'] as String?) ?? AccessMethod.manual,
      );

  final String sessionId;
  final Subject subject;
  final DateTime checkInTime;
  final Duration duration;
  final AccessMethod checkInMethod;
}
