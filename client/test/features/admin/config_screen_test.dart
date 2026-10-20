import 'package:client/core/network/api_error.dart';
import 'package:client/core/theme/app_theme.dart';
import 'package:client/features/admin/presentation/config_screen.dart';
import 'package:client/features/system_config/data/models/system_config.dart';
import 'package:client/features/system_config/data/system_config_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class ConfigRepositoryFake implements SystemConfigRepository {
  Map<String, dynamic> json = {
    'timezone': 'Asia/Ho_Chi_Minh',
    'openingHours': [
      for (var d = 1; d <= 7; d++)
        {'dayOfWeek': d, 'opensAt': '08:00', 'closesAt': '22:00'}
    ],
    'maxCapacity': 250,
    'nearCapacityRatio': .9,
    'capacityEnforcement': false,
    'scanCooldownSeconds': 10,
    'version': 4,
  };
  Map<String, dynamic>? saved;
  ApiException? error;
  int calls = 0;
  @override
  Future<SystemConfig> fetch() async => SystemConfig.fromJson(json);
  @override
  Future<SystemConfig> update(Map<String, dynamic> patch) async {
    calls++;
    if (error != null) throw error!;
    saved = Map.of(patch);
    json = {...json, ...patch, 'version': (json['version'] as int) + 1};
    return SystemConfig.fromJson(json);
  }
}

Future<void> pumpConfig(WidgetTester tester, ConfigRepositoryFake repository,
    {Size size = const Size(1200, 1100)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        systemConfigRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ConfigScreen()))));
  await tester.pumpAndSettle();
}

Future<void> tapSave(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Lưu cấu hình'));
  await tester.tap(find.text('Lưu cấu hình'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ADM-17 validates capacity before saving and keeps saved values',
      (tester) async {
    final repo = ConfigRepositoryFake();
    await pumpConfig(tester, repo);
    await tester.enterText(find.byKey(const ValueKey('capacity')), '0');
    await tapSave(tester);
    expect(repo.calls, 0);
    expect(find.text('Nhập số nguyên từ 1 đến 100000'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('capacity')), '300');
    await tester.enterText(find.byKey(const ValueKey('ratio')), '85,5');
    await tapSave(tester);
    expect(repo.saved?['version'], 4);
    expect(repo.saved?['maxCapacity'], 300);
    expect(repo.saved?['nearCapacityRatio'], .855);
    expect(find.text('Cấu hình đã được đồng bộ'), findsOneWidget);
    expect(find.text('300'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel restores capacity and opening hours without an API write',
      (tester) async {
    final repo = ConfigRepositoryFake();
    await pumpConfig(tester, repo);
    await tester.tap(find.byKey(const ValueKey('opening-day-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    expect(find.text('Đóng cửa'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('capacity')), '350');
    await tester.tap(find.text('Hủy thay đổi'));
    await tester.pumpAndSettle();
    expect(find.text('250'), findsOneWidget);
    expect(find.text('Đóng cửa'), findsNothing);
    expect(repo.calls, 0);
  });

  testWidgets('failed save retains draft for retry', (tester) async {
    final repo = ConfigRepositoryFake()
      ..error = const ApiException(code: ClientErrorCode.network);
    await pumpConfig(tester, repo);
    await tester.enterText(find.byKey(const ValueKey('capacity')), '300');
    await tapSave(tester);
    expect(find.text('Bạn có thay đổi chưa lưu'), findsOneWidget);
    expect(find.text('300'), findsOneWidget);
    repo.error = null;
    await tapSave(tester);
    expect(repo.saved?['maxCapacity'], 300);
    expect(tester.takeException(), isNull);
  });

  testWidgets('operational settings fit narrow screens', (tester) async {
    await pumpConfig(tester, ConfigRepositoryFake(),
        size: const Size(390, 844));
    await tester.ensureVisible(find.text('Lưu cấu hình'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
