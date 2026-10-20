import 'package:client/core/theme/app_theme.dart';
import 'package:client/features/admin/application/admin_providers.dart';
import 'package:client/features/admin/data/admin_models.dart';
import 'package:client/features/admin/presentation/analytics_screen.dart';
import 'package:client/features/admin/presentation/widgets/recognition_analytics_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const recognition = RecognitionAnalytics(
  totalAttempts: 1920,
  matched: 1738,
  failed: 182,
  failureRate: .09479,
  p50LatencyMs: 420,
  p95LatencyMs: 1180,
  outcomes: [
    OutcomeCount(outcome: 'NO_MATCH', count: 86),
    OutcomeCount(outcome: 'LIVENESS_FAILED', count: 42),
    OutcomeCount(outcome: 'LOW_QUALITY', count: 31),
    OutcomeCount(outcome: 'SERVICE_UNAVAILABLE', count: 23),
  ],
);

void main() {
  testWidgets('ADM-16 opens from analytics and formats Vietnamese metrics',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          accessAnalyticsProvider.overrideWith((_) async =>
              const AccessAnalytics(
                  totalCheckIns: 0,
                  totalCheckOuts: 0,
                  averageStaySeconds: null,
                  buckets: [])),
          recognitionAnalyticsProvider.overrideWith((_) async => recognition),
        ],
        child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: AnalyticsScreen()))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhận diện khuôn mặt'));
    await tester.pumpAndSettle();
    expect(find.text('1.920'), findsOneWidget);
    expect(find.text('9,5%'), findsOneWidget);
    expect(find.text('1.180 ms'), findsOneWidget);
    expect(find.text('86'), findsOneWidget);
    expect(find.textContaining('Đây không phải độ chính xác của AI.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recognition results fit a phone and retain full outcome labels',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
            body: SingleChildScrollView(
                child: Padding(
          padding: EdgeInsets.all(16),
          child: RecognitionAnalyticsBody(data: recognition),
        )))));
    await tester.pumpAndSettle();
    expect(find.text('Không đạt kiểm tra người thật'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
