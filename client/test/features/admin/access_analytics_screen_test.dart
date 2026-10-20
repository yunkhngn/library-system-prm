import 'package:client/core/theme/app_theme.dart';
import 'package:client/features/admin/application/admin_providers.dart';
import 'package:client/features/admin/data/admin_models.dart';
import 'package:client/features/admin/presentation/analytics_screen.dart';
import 'package:client/features/admin/presentation/widgets/access_analytics_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AccessAnalytics sampleAccess({int count = 7}) => AccessAnalytics(
      totalCheckIns: 2846,
      totalCheckOuts: 2791,
      averageStaySeconds: 6720,
      buckets: List.generate(
          count,
          (i) => AccessBucket(
                startsAt: DateTime.utc(2026, 10, 7, i),
                endsAt: DateTime.utc(2026, 10, 7, i + 1),
                checkIns: 100 + i,
                checkOuts: 90 + i,
                faceCheckIns: 61,
                qrCheckIns: 33,
                manualCheckIns: 6,
              )),
    );

void main() {
  testWidgets('ADM-15 renders API totals, method shares and hourly labels',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          accessAnalyticsProvider.overrideWith((_) async => sampleAccess()),
        ],
        child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: AnalyticsScreen()))));
    await tester.pumpAndSettle();
    expect(find.text('2.846'), findsOneWidget);
    expect(find.text('2.791'), findsOneWidget);
    expect(find.text('1 giờ 52 phút'), findsOneWidget);
    expect(find.text('61%'), findsOneWidget);
    expect(find.text('33%'), findsOneWidget);
    await tester.tap(find.text('Theo giờ'));
    await tester.pumpAndSettle();
    expect(find.text('07:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long hourly range fits a phone without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
            body: SingleChildScrollView(
                child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              AccessAnalyticsBody(data: sampleAccess(count: 48), hourly: true),
        )))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty range has no invented counts or average', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
            body: SingleChildScrollView(
          child: AccessAnalyticsBody(
              hourly: false,
              data: AccessAnalytics(
                totalCheckIns: 0,
                totalCheckOuts: 0,
                averageStaySeconds: null,
                buckets: [],
              )),
        ))));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có dữ liệu ra vào'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
