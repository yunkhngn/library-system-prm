import 'package:client/core/network/api_error.dart';
import 'package:client/core/theme/app_theme.dart';
import 'package:client/features/student/application/student_rules_provider.dart';
import 'package:client/features/student/presentation/student_rules_screen.dart';
import 'package:client/features/system_config/data/models/system_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SystemConfig _config({bool closedSunday = false}) => SystemConfig(
    timezone: 'Asia/Ho_Chi_Minh',
    openingHours: [
      for (var d = 1; d <= (closedSunday ? 6 : 7); d++)
        OpeningSlot(dayOfWeek: d, opensAt: '08:00', closesAt: '22:00')
    ],
    maxCapacity: 250,
    nearCapacityRatio: .9,
    capacityEnforcement: false,
    maxSessionDurationMinutes: null,
    scanCooldownSeconds: 10,
    version: 1,
    updatedAt: null);

Future<void> _pump(WidgetTester tester, Future<SystemConfig> Function() load,
    {double scale = 1}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
      overrides: [studentRulesProvider.overrideWith((ref) => load())],
      child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
              body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: const StudentRulesScreen())))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('STU-08 renders actual configuration without editing controls',
      (tester) async {
    await _pump(tester, () async => _config());
    expect(find.text('08:00 – 22:00 mỗi ngày'), findsOneWidget);
    expect(find.text('250 người'), findsOneWidget);
    expect(find.text('Có hiệu lực trong 30 giây'), findsOneWidget);
    expect(find.text('10 giây'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('nonuniform hours show closed days and large text scrolls',
      (tester) async {
    await _pump(tester, () async => _config(closedSunday: true), scale: 1.5);
    expect(find.textContaining('Chủ Nhật: Đóng cửa'), findsOneWidget);
    expect(find.textContaining('mỗi ngày'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed load retries without showing fabricated rules',
      (tester) async {
    var calls = 0;
    await _pump(tester, () async {
      if (calls++ == 0) throw const ApiException(code: ClientErrorCode.network);
      return _config();
    });
    expect(find.text('250 người'), findsNothing);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('250 người'), findsOneWidget);
    expect(calls, 2);
  });
}
