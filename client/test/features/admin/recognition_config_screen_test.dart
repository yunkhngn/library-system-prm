import 'package:client/core/network/api_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'config_screen_test.dart' show ConfigRepositoryFake, pumpConfig, tapSave;

Future<void> enterRecognition(WidgetTester tester) async {
  await tester.tap(find.text('Nhận diện'));
  await tester.pumpAndSettle();
}

Future<void> fillCalibration(WidgetTester tester) async {
  for (final entry in {
    'face-model': 'arcface-v1',
    'face-cosine': '0,65',
    'face-gap': '0.1',
    'face-liveness': '0.8',
  }.entries) {
    await tester.enterText(find.byKey(ValueKey(entry.key)), entry.value);
  }
}

void main() {
  testWidgets(
      'ADM-18 rejects partial and non-numeric calibration then saves only recognition fields',
      (tester) async {
    final repo = ConfigRepositoryFake();
    await pumpConfig(tester, repo);
    await enterRecognition(tester);
    expect(find.text('Chưa cấu hình'), findsWidgets);
    await tester.enterText(
        find.byKey(const ValueKey('face-model')), 'arcface-v1');
    await tapSave(tester);
    expect(repo.calls, 0);
    await fillCalibration(tester);
    await tester.enterText(find.byKey(const ValueKey('face-cosine')), 'NaN');
    await tapSave(tester);
    expect(repo.calls, 0);
    await tester.enterText(find.byKey(const ValueKey('face-cosine')), '0,65');
    await tapSave(tester);
    expect(repo.saved?['faceMaxCosineDistance'], .65);
    expect(repo.saved?.containsKey('maxCapacity'), isFalse);
    expect(repo.saved?['version'], 4);
    expect(find.text('Đã cấu hình'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'clearing all fields sends an explicit reset rather than null patch',
      (tester) async {
    final repo = ConfigRepositoryFake();
    repo.json.addAll({
      'faceModelVersion': 'arcface-v1',
      'faceMaxCosineDistance': .65,
      'faceMinDistanceGap': .1,
      'livenessMinScore': .8,
    });
    await pumpConfig(tester, repo);
    await enterRecognition(tester);
    for (final key in [
      'face-model',
      'face-cosine',
      'face-gap',
      'face-liveness'
    ]) {
      await tester.enterText(find.byKey(ValueKey(key)), '');
    }
    await tapSave(tester);
    expect(repo.saved, {'version': 4, 'resetFaceConfiguration': true});
    expect(repo.json['faceModelVersion'], isNull);
    expect(find.text('Đã cấu hình'), findsNothing);
  });

  testWidgets('changing tabs asks before discarding an unsaved draft',
      (tester) async {
    await pumpConfig(tester, ConfigRepositoryFake());
    await enterRecognition(tester);
    await tester.enterText(
        find.byKey(const ValueKey('face-model')), 'draft-model');
    await tester.tap(find.text('Vận hành'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp tục chỉnh sửa'));
    await tester.pumpAndSettle();
    expect(find.text('draft-model'), findsOneWidget);
    await tester.tap(find.text('Vận hành'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ thay đổi'));
    await tester.pumpAndSettle();
    expect(find.text('Giờ mở cửa'), findsOneWidget);
  });

  testWidgets('conflict keeps draft and offers an explicit reload',
      (tester) async {
    final repo = ConfigRepositoryFake()
      ..error = const ApiException(code: 'VERSION_CONFLICT', statusCode: 409);
    await pumpConfig(tester, repo);
    await enterRecognition(tester);
    await fillCalibration(tester);
    await tapSave(tester);
    expect(find.text('Bạn có thay đổi chưa lưu'), findsOneWidget);
    expect(find.text('Tải bản mới'), findsOneWidget);
    repo.json['version'] = 5;
    await tester.tap(find.text('Tải bản mới'));
    await tester.pumpAndSettle();
    expect(find.text('arcface-v1'), findsNothing);
    expect(find.text('Cấu hình đã được đồng bộ'), findsOneWidget);
  });

  testWidgets('advanced form fits a phone', (tester) async {
    await pumpConfig(tester, ConfigRepositoryFake(),
        size: const Size(390, 844));
    await enterRecognition(tester);
    await tester.ensureVisible(find.text('Lưu cấu hình'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
