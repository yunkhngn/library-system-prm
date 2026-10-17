import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/actor.dart';
import 'subject.dart';

class AccessSession {
  const AccessSession({
    required this.id,
    required this.subject,
    required this.checkInTime,
    required this.checkOutTime,
    required this.checkInMethod,
    required this.checkOutMethod,
    required this.checkInKiosk,
    required this.checkOutKiosk,
    required this.checkInBy,
    required this.checkOutBy,
    required this.checkoutReason,
    required this.manualReason,
    required this.checkOutManualReason,
    required this.duration,
  });

  factory AccessSession.fromJson(Map<String, dynamic> json) => AccessSession(
        id: json['id'] as String,
        subject: Subject.fromJson(json['subject'] as Map<String, dynamic>),
        checkInTime: DateTime.parse(json['checkInTime'] as String),
        checkOutTime:
            json['checkOutTime'] == null ? null : DateTime.parse(json['checkOutTime'] as String),
        checkInMethod: AccessMethod.tryParse(json['checkInMethod'] as String?),
        checkOutMethod: AccessMethod.tryParse(json['checkOutMethod'] as String?),
        checkInKiosk: json['checkInKiosk'] == null
            ? null
            : KioskSummary.fromJson(json['checkInKiosk'] as Map<String, dynamic>),
        checkOutKiosk: json['checkOutKiosk'] == null
            ? null
            : KioskSummary.fromJson(json['checkOutKiosk'] as Map<String, dynamic>),
        checkInBy: json['checkInBy'] == null
            ? null
            : Actor.fromJson(json['checkInBy'] as Map<String, dynamic>),
        checkOutBy: json['checkOutBy'] == null
            ? null
            : Actor.fromJson(json['checkOutBy'] as Map<String, dynamic>),
        checkoutReason: json['checkoutReason'] as String?,
        manualReason: json['manualReason'] as String?,
        checkOutManualReason: json['checkOutManualReason'] as String?,
        duration: Duration(seconds: (json['durationSeconds'] as num?)?.toInt() ?? 0),
      );

  final String id;
  final Subject subject;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final AccessMethod? checkInMethod;
  final AccessMethod? checkOutMethod;
  final KioskSummary? checkInKiosk;
  final KioskSummary? checkOutKiosk;
  final Actor? checkInBy;
  final Actor? checkOutBy;
  final String? checkoutReason;
  final String? manualReason;
  final String? checkOutManualReason;
  final Duration duration;

  bool get isOpen => checkOutTime == null;

  /// Automatic closures have no staff actor; explain them in Vietnamese.
  String? get autoCloseExplanation {
    final time = checkOutTime;
    return switch (checkoutReason) {
      'CLOSING_TIME' =>
        'Đóng tự động do đến giờ đóng cửa${time == null ? '' : ' (${Fmt.time(time)})'}',
      'MAX_DURATION' => 'Đóng tự động do hết thời gian lưu lại tối đa',
      _ => null,
    };
  }
}
