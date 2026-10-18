import 'package:client/core/network/api_error.dart';
import 'package:client/features/librarian/library_rules/presentation/library_rules_screen.dart';
import 'package:client/features/system_config/data/models/system_config.dart';
import 'package:client/features/system_config/data/system_config_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConfigRepository implements SystemConfigRepository {
  _FakeConfigRepository(this.result);

  Object result;
  int calls = 0;

  @override
  Future<SystemConfig> fetch() async {
    calls++;
    final r = result;
    if (r is SystemConfig) return r;
    throw r;
  }

  @override
  Future<SystemConfig> update(Map<String, dynamic> patch) async {
    final r = result;
    if (r is SystemConfig) return r;
    throw r;
  }
}

SystemConfig _config({int? maxStay, bool enforce = false}) => SystemConfig(
      timezone: 'Asia/Ho_Chi_Minh',
      openingHours: [
        for (var d = 1; d <= 6; d++) OpeningSlot(dayOfWeek: d, opensAt: '08:00', closesAt: '22:00'),
      ],
      maxCapacity: 250,
      nearCapacityRatio: 0.9,
      capacityEnforcement: enforce,
      maxSessionDurationMinutes: maxStay,
      scanCooldownSeconds: 10,
      version: 1,
      updatedAt: DateTime.utc(2026, 10, 15, 9, 13),
    );

Future<void> _pump(WidgetTester tester, _FakeConfigRepository repo) async {
  tester.view.physicalSize = const Size(1440, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [systemConfigRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: Scaffold(body: LibraryRulesScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows opening hours, limits and the out-of-hours rule', (tester) async {
    await _pump(tester, _FakeConfigRepository(_config()));

    expect(find.text('Giờ mở cửa'), findsOneWidget);
    expect(find.text('Thứ Hai'), findsOneWidget);
    expect(find.text('08:00 – 22:00'), findsNWidgets(6));
    expect(find.text('Đóng cửa'), findsOneWidget, reason: 'Sunday has no slot');
    expect(find.text('250 người'), findsOneWidget);
    expect(find.text('Không giới hạn'), findsOneWidget);
    expect(find.text('10 giây'), findsOneWidget);
    expect(find.textContaining('không thể ghi nhận vào'), findsOneWidget);
    expect(find.textContaining('Cảnh báo gần đầy từ 225 người'), findsOneWidget);
    expect(find.byType(TextField), findsNothing, reason: 'LIB-08 is read-only');
  });

  testWidgets('formats a maximum stay and capacity enforcement', (tester) async {
    await _pump(tester, _FakeConfigRepository(_config(maxStay: 240, enforce: true)));

    expect(find.text('4 giờ'), findsOneWidget);
    expect(find.textContaining('Không thể ghi nhận vào khi thư viện đã đủ người'), findsOneWidget);
  });

  testWidgets('shows an error with retry and recovers', (tester) async {
    final repo = _FakeConfigRepository(const ApiException(code: ClientErrorCode.network));
    await _pump(tester, repo);

    expect(find.text('Không tải được dữ liệu'), findsOneWidget);

    repo.result = _config();
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.text('250 người'), findsOneWidget);
    expect(repo.calls, 2);
  });
}
