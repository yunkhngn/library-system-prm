import 'dart:typed_data';
import 'package:client/core/network/api_error.dart';
import 'package:client/core/theme/app_theme.dart';
import 'package:client/features/kiosk/application/kiosk_controller.dart';
import 'package:client/features/kiosk/presentation/kiosk_ready_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'kiosk_fakes.dart';

void main() {
  for (final size in [
    const Size(1200, 800),
    const Size(800, 700),
    const Size(390, 844)
  ]) {
    testWidgets('KSK-02 shows controls without overflow at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var face = 0, qr = 0;
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: Padding(
            padding: const EdgeInsets.all(24),
            child: KioskReadyScreen(
                camera: const ColoredBox(color: Colors.black),
                connected: true,
                online: true,
                busy: false,
                faceEnabled: true,
                onConnect: () {},
                onFace: () => face++,
                onQr: () => qr++),
          )))));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bắt đầu nhận diện'));
      await tester.tap(find.text('Bắt đầu nhận diện'));
      await tester.ensureVisible(find.text('Sử dụng mã QR'));
      await tester.tap(find.text('Sử dụng mã QR'));
      expect(face, 1);
      expect(qr, 1);
      expect(find.text('Đang kết nối trực tiếp'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test('uncertain writes block another scan and recover the original request',
      () async {
    final repo = FakeKioskRepository()
      ..failure = const ApiException(code: ClientErrorCode.timeout);
    final controller = KioskController(repo);
    addTearDown(controller.dispose);
    await controller.connect('id', 'credential');
    await controller.scanQr('token');
    expect(controller.pendingKey, repo.usedKey);
    await controller.scanQr('second-token');
    expect(repo.qrCalls, 1);
    await controller.checkPending();
    expect(controller.result, kioskResult);
    expect(controller.pendingKey, isNull);
  });

  test('capture rejects an unknown container and erases transient video bytes',
      () async {
    final repo = FakeKioskRepository();
    final controller = KioskController(repo);
    addTearDown(controller.dispose);
    await controller.connect('id', 'credential');
    final bytes = Uint8List.fromList(List.filled(12, 5));
    await controller.recognize((_) async => bytes);
    expect(controller.error?.code, 'VIDEO_FORMAT_UNSUPPORTED');
    expect(repo.faceCalls, 0);
    expect(bytes, everyElement(0));
  });

  test('capture accepts a WebM recording (browser kiosk)', () async {
    final repo = FakeKioskRepository();
    final controller = KioskController(repo);
    addTearDown(controller.dispose);
    await controller.connect('id', 'credential');
    final bytes = Uint8List.fromList(
        [0x1A, 0x45, 0xDF, 0xA3, ...List.filled(40, 1)]);
    await controller.recognize((_) async => bytes);
    expect(controller.error, isNull);
    expect(repo.faceCalls, 1);
    expect(controller.result, kioskResult);
    expect(bytes, everyElement(0), reason: 'transient video bytes are erased');
  });

  test('capture accepts an MP4 recording (mobile kiosk)', () async {
    final repo = FakeKioskRepository();
    final controller = KioskController(repo);
    addTearDown(controller.dispose);
    await controller.connect('id', 'credential');
    final bytes = Uint8List.fromList(
        [0, 0, 0, 0x20, 0x66, 0x74, 0x79, 0x70, ...List.filled(40, 1)]);
    await controller.recognize((_) async => bytes);
    expect(controller.error, isNull);
    expect(repo.faceCalls, 1);
  });
}
