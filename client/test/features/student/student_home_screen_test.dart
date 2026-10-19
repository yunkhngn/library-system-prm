import 'dart:io';
import 'dart:ui' as ui;

import 'package:client/app/routes.dart';
import 'package:client/core/network/api_error.dart';
import 'package:client/core/theme/app_theme.dart';
import 'package:client/features/access/data/models/access_session.dart';
import 'package:client/features/auth/data/models/user.dart';
import 'package:client/features/student/application/student_home_provider.dart';
import 'package:client/features/student/data/student_home_repository.dart';
import 'package:client/features/student/presentation/student_home_screen.dart';
import 'package:client/features/student/presentation/student_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final _now = DateTime.parse('2026-10-13T14:25:00+07:00');
const _captureKey = ValueKey('capture');

AccessSession _visit(String id, String entry, [String? exit]) =>
    AccessSession.fromJson({
      'id': id,
      'subject': {
        'id': 'sv1',
        'kind': 'USER',
        'code': 'SV001',
        'fullName': 'Nguyễn Thị Huyền'
      },
      'checkInTime': entry,
      'checkOutTime': exit,
      'checkInMethod': 'FACE',
      'checkInKiosk': {
        'id': 'k1',
        'code': 'K1',
        'name': 'Cổng chính – Lối vào'
      },
    });

StudentHomeData _data(
    {bool inside = true, bool enrolled = false, bool empty = false}) {
  final current = _visit('s1', '2026-10-13T13:05:00+07:00');
  return StudentHomeData(
    user: User(
        id: 'sv1',
        code: 'SV001',
        email: 'huyen@example.edu.vn',
        fullName: 'Nguyễn Thị Huyền',
        role: UserRole.student,
        status: 'ACTIVE',
        mustChangePassword: false,
        faceEnrolled: enrolled,
        version: 1),
    status: StudentAccessStatus(
        isInside: inside, currentSession: inside ? current : null, asOf: _now),
    faceEnrolledAt:
        enrolled ? DateTime.parse('2026-10-01T08:00:00+07:00') : null,
    recent: empty
        ? []
        : [
            if (inside) current,
            _visit(
                's2', '2026-10-12T08:15:00+07:00', '2026-10-12T11:40:00+07:00'),
            _visit(
                's3', '2026-10-10T09:02:00+07:00', '2026-10-10T12:10:00+07:00'),
          ],
  );
}

Future<GoRouter> _pump(
  WidgetTester tester, {
  required Future<StudentHomeData> Function() load,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: Routes.studentHome, routes: [
    ShellRoute(builder: (_, __, child) => StudentShell(child: child), routes: [
      GoRoute(
          path: Routes.studentHome,
          builder: (_, __) => const StudentHomeScreen()),
      for (final path in [
        Routes.studentQr,
        Routes.studentHistory,
        Routes.studentAccount,
        Routes.studentFace,
        '${Routes.studentHistory}/:id'
      ])
        GoRoute(
            path: path,
            builder: (_, state) => Text('Destination: ${state.uri.path}')),
    ]),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        studentHomeProvider.overrideWith((ref) => load()),
        studentClockProvider.overrideWithValue(() => _now),
      ],
      child: RepaintBoundary(
          key: _captureKey,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!),
          ))));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('BeVietnamPro');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/BeVietnamPro-$weight.ttf'));
    }
    await loader.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  testWidgets('STU-01 shows live student data and opens personal QR',
      (tester) async {
    final router = await _pump(tester, load: () async => _data());
    expect(find.text('Xin chào, Huyền'), findsOneWidget);
    expect(find.text('Thứ Ba, 13/10/2026'), findsOneWidget);
    expect(find.text('Đang trong thư viện'), findsOneWidget);
    expect(find.text('Vào lúc 13:05'), findsOneWidget);
    expect(find.text('Đã ở 1 giờ 20 phút'), findsOneWidget);
    expect(find.text('Vào 08:15 → Ra 11:40'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_STU01')) {
      final boundary =
          tester.renderObject<RenderRepaintBoundary>(find.byKey(_captureKey));
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/previews').create(recursive: true);
        await File('build/previews/stu-01.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.tap(find.text('Mở mã QR ra vào'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, Routes.studentQr);
  });

  testWidgets('outside and empty history never imply an open visit',
      (tester) async {
    await _pump(tester,
        load: () async => _data(inside: false, empty: true, enrolled: true));
    expect(find.text('Ngoài thư viện'), findsOneWidget);
    expect(find.text('Vào lúc 13:05'), findsNothing);
    expect(find.text('Chưa có lượt ra gần đây'), findsOneWidget);
    expect(find.text('Lượt ra vào gần đây'), findsNothing);
    expect(find.text('Đã đăng ký · 01/10/2026'), findsOneWidget);
    await tester.tap(find.text('Nhận diện khuôn mặt'));
    await tester.pumpAndSettle();
    expect(find.text('Destination: ${Routes.studentFace}'), findsOneWidget);
  });

  testWidgets(
      'STU-10 shows last exit, compact enrollment card and QR navigation',
      (tester) async {
    final router = await _pump(tester,
        load: () async => _data(inside: false, enrolled: true));
    expect(find.text('Trạng thái ngoài thư viện'), findsOneWidget);
    expect(find.text('12/10/2026 lúc 11:40'), findsOneWidget);
    expect(find.text('Lượt ra vào gần đây'), findsNothing);
    expect(find.text('Đã đăng ký · 01/10/2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_STU10')) {
      final boundary =
          tester.renderObject<RenderRepaintBoundary>(find.byKey(_captureKey));
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/previews').create(recursive: true);
        await File('build/previews/stu-10.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.tap(find.text('Mở mã QR ra vào'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, Routes.studentQr);
  });

  testWidgets(
      'network failure retries instead of showing a false outside state',
      (tester) async {
    var calls = 0;
    await _pump(tester, load: () async {
      if (calls++ == 0) throw const ApiException(code: ClientErrorCode.network);
      return _data();
    });
    expect(find.text('Không tải được dữ liệu'), findsOneWidget);
    expect(find.text('Ngoài thư viện'), findsNothing);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Đang trong thư viện'), findsOneWidget);
  });

  testWidgets(
      'small screens and large text scroll without overflow; tabs navigate',
      (tester) async {
    final router = await _pump(tester,
        load: () async => _data(), size: const Size(320, 640), textScale: 1.5);
    await tester.drag(find.byType(ListView), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Lịch sử'));
    await tester.pumpAndSettle();
    expect(
        router.routeInformationProvider.value.uri.path, Routes.studentHistory);
  });

  testWidgets('recent session opens its own detail route', (tester) async {
    final router = await _pump(tester, load: () async => _data());
    await tester.ensureVisible(find.text('Vào 08:15 → Ra 11:40'));
    await tester.tap(find.text('Vào 08:15 → Ra 11:40'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path,
        Routes.studentHistoryDetail('s2'));
  });
}
