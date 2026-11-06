import 'package:client/core/network/api_error.dart';
import 'package:client/features/kiosk/application/kiosk_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kiosk_fakes.dart';

void main() {
  test('connect normalizes the kiosk code and remembers the login', () async {
    final repo = FakeKioskRepository();
    final store = MemoryKioskCredentialStore();
    final controller = KioskController(repo, store);
    addTearDown(controller.dispose);

    await controller.connect(' kiosk-01 ', 'k' * 40);

    expect(repo.lastCode, 'KIOSK-01');
    expect(controller.session, isNotNull);
    expect(store.value?.code, 'KIOSK-01');
  });

  test('restore reconnects with the saved login after a reload', () async {
    final repo = FakeKioskRepository();
    final store = MemoryKioskCredentialStore()
      ..value = (code: 'KIOSK-01', credential: 'k' * 40);
    final controller = KioskController(repo, store);
    addTearDown(controller.dispose);

    await controller.restore();

    expect(repo.connectCalls, 1);
    expect(controller.session, isNotNull);
    expect(controller.restoring, isFalse);
  });

  test('an expired kiosk token signs in again without dropping the session',
      () async {
    final repo = FakeKioskRepository();
    final controller = KioskController(repo, MemoryKioskCredentialStore());
    addTearDown(controller.dispose);
    await controller.connect('KIOSK-01', 'k' * 40);
    await Future<void>.delayed(Duration.zero); // initial heartbeat

    repo.heartbeatFailure =
        const ApiException(code: 'UNAUTHENTICATED', statusCode: 401);
    await controller.ping();

    expect(repo.connectCalls, 2);
    expect(controller.session, isNotNull);
    expect(controller.error, isNull);
  });

  test('a rejected saved key is forgotten', () async {
    final repo = FakeKioskRepository()
      ..connectFailure =
          const ApiException(code: 'INVALID_CREDENTIALS', statusCode: 401);
    final store = MemoryKioskCredentialStore()
      ..value = (code: 'KIOSK-01', credential: 'k' * 40);
    final controller = KioskController(repo, store);
    addTearDown(controller.dispose);

    await controller.restore();

    expect(controller.session, isNull);
    expect(controller.hasSavedLogin, isFalse);
    expect(store.value, isNull);
  });

  test('a network failure keeps the saved login for a retry', () async {
    final repo = FakeKioskRepository()
      ..connectFailure = const ApiException(code: ClientErrorCode.timeout);
    final store = MemoryKioskCredentialStore()
      ..value = (code: 'KIOSK-01', credential: 'k' * 40);
    final controller = KioskController(repo, store);
    addTearDown(controller.dispose);

    await controller.restore();

    expect(controller.session, isNull);
    expect(controller.hasSavedLogin, isTrue);
    expect(store.value, isNotNull);
  });

  test('disconnect forgets the device login', () async {
    final store = MemoryKioskCredentialStore();
    final controller = KioskController(FakeKioskRepository(), store);
    addTearDown(controller.dispose);
    await controller.connect('KIOSK-01', 'k' * 40);

    await controller.disconnect();

    expect(controller.session, isNull);
    expect(store.value, isNull);
  });
}
