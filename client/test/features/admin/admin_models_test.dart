import 'package:flutter_test/flutter_test.dart';
import 'package:client/features/admin/data/admin_models.dart';

void main() {
  group('Admin models', () {
    test('parses kiosk credential using backend credential field', () {
      final result = KioskCredential.fromJson({
        'kiosk': {
          'id': 'kiosk-id',
          'code': 'KIOSK-01',
          'name': 'Cổng chính',
          'mode': 'AUTO',
          'status': 'ACTIVE',
          'isOnline': true,
          'lastSeenAt': '2026-10-18T08:00:00+07:00',
          'version': 3,
        },
        'credential': 'one-time-secret',
      });

      expect(result.credential, 'one-time-secret');
      expect(result.kiosk.code, 'KIOSK-01');
      expect(result.kiosk.isOnline, isTrue);
    });

    test('aggregates access methods from buckets', () {
      final result = AccessAnalytics.fromJson({
        'totalCheckIns': 10,
        'totalCheckOuts': 8,
        'averageStaySeconds': 3600,
        'buckets': [
          {
            'startsAt': '2026-10-18T00:00:00+07:00',
            'endsAt': '2026-10-19T00:00:00+07:00',
            'checkIns': 10,
            'checkOuts': 8,
            'faceCheckIns': 5,
            'qrCheckIns': 3,
            'manualCheckIns': 2,
          },
        ],
      });

      expect(result.totalMethodCheckIns, 10);
      expect(result.methodCount('FACE'), 5);
      expect(result.methodCount('QR'), 3);
      expect(result.methodCount('MANUAL'), 2);
    });

    test(
        'reads recognition outcome list instead of nonexistent top-level fields',
        () {
      final result = RecognitionAnalytics.fromJson({
        'totalAttempts': 12,
        'matched': 7,
        'failed': 5,
        'failureRate': 0.4167,
        'p50LatencyMs': 120,
        'p95LatencyMs': 280,
        'outcomes': [
          {'outcome': 'NO_MATCH', 'count': 3},
          {'outcome': 'LIVENESS_FAILED', 'count': 2},
        ],
      });

      expect(result.outcomeCount('NO_MATCH'), 3);
      expect(result.outcomeCount('LIVENESS_FAILED'), 2);
      expect(result.failed, 5);
    });

    test('parses immutable account and shift DTOs', () {
      final account = AdminAccount.fromJson({
        'id': 'user-id',
        'code': 'SV001',
        'email': 'sv001@example.edu.vn',
        'fullName': 'Nguyễn Văn A',
        'role': 'STUDENT',
        'status': 'ACTIVE',
        'mustChangePassword': true,
        'faceEnrolled': false,
        'version': 1,
      });
      final shift = AdminShift.fromJson({
        'id': 'shift-id',
        'name': 'Ca sáng',
        'startsAt': '2026-10-18T07:30:00+07:00',
        'endsAt': '2026-10-18T12:00:00+07:00',
        'status': 'ACTIVE',
        'version': 2,
        'assignmentCount': 4,
      });

      expect(account.fullName, 'Nguyễn Văn A');
      expect(shift.assignmentCount, 4);
      expect(shift.endsAt.isAfter(shift.startsAt), isTrue);
    });
  });
}
