import 'subject.dart';

class AccessResult {
  const AccessResult({
    required this.requestId,
    required this.sessionId,
    required this.action,
    required this.subject,
    required this.method,
    required this.occurredAt,
  });

  factory AccessResult.fromJson(Map<String, dynamic> json) => AccessResult(
        requestId: json['requestId'] as String,
        sessionId: json['sessionId'] as String,
        action: AccessAction.parse(json['action'] as String?),
        subject: Subject.fromJson(json['subject'] as Map<String, dynamic>),
        method: AccessMethod.tryParse(json['method'] as String?) ?? AccessMethod.manual,
        occurredAt: DateTime.parse(json['occurredAt'] as String),
      );

  final String requestId;
  final String sessionId;
  final AccessAction action;
  final Subject subject;
  final AccessMethod method;
  final DateTime occurredAt;
}

enum AccessRequestState { inProgress, completed }

class AccessRequestStatus {
  const AccessRequestStatus({
    required this.status,
    required this.httpStatus,
    required this.result,
    required this.errorCode,
  });

  factory AccessRequestStatus.fromJson(Map<String, dynamic> json) {
    final error = json['error'];
    return AccessRequestStatus(
      status: (json['status'] as String?)?.toUpperCase() == 'COMPLETED'
          ? AccessRequestState.completed
          : AccessRequestState.inProgress,
      httpStatus: (json['httpStatus'] as num?)?.toInt(),
      result: json['result'] == null
          ? null
          : AccessResult.fromJson(json['result'] as Map<String, dynamic>),
      errorCode: error is Map<String, dynamic> ? error['code'] as String? : null,
    );
  }

  final AccessRequestState status;
  final int? httpStatus;
  final AccessResult? result;
  final String? errorCode;
}