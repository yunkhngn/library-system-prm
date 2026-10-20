import 'dart:typed_data';
import 'package:client/features/kiosk/data/kiosk_repository.dart';
import 'package:client/features/access/data/models/access_result.dart';
import 'package:client/features/access/data/models/subject.dart';

final kioskResult = AccessResult(
  requestId: 'request',
  sessionId: 'session',
  action: AccessAction.checkIn,
  subject: const Subject(
      id: 'student',
      kind: SubjectKind.user,
      code: 'SV001',
      fullName: 'Nguyễn Thị Huyền'),
  method: AccessMethod.face,
  occurredAt: DateTime.utc(2026, 10, 20, 6, 5),
);

class FakeKioskRepository implements KioskRepository {
  int qrCalls = 0, faceCalls = 0;
  Object? failure;
  String? usedKey;
  AccessRequestStatus recovery = AccessRequestStatus(
      status: AccessRequestState.completed,
      httpStatus: 200,
      result: kioskResult,
      errorCode: null);
  @override
  Future<KioskSession> connect(String id, String credential) async =>
      const KioskSession(
          name: 'Cổng chính · Lối vào', mode: 'ENTRY', faceEnabled: true);
  @override
  Future<void> heartbeat(String status) async {}
  @override
  Future<KioskChallenge> challenge() async => KioskChallenge(
      id: 'challenge',
      expiresAt: DateTime.now().add(const Duration(minutes: 1)),
      instructions: ['Chớp mắt']);
  @override
  Future<AccessResult> face(
      KioskChallenge challenge, Uint8List clip, String key) async {
    faceCalls++;
    usedKey = key;
    if (failure != null) throw failure!;
    return kioskResult;
  }

  @override
  Future<AccessResult> qr(String token, String key) async {
    qrCalls++;
    usedKey = key;
    if (failure != null) throw failure!;
    return kioskResult;
  }

  @override
  Future<AccessRequestStatus> status(String key) async => recovery;
}
