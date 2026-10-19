import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:client/app/routes.dart';
import 'package:client/core/network/api_error.dart';
import 'package:client/core/theme/app_theme.dart';
import 'package:client/features/auth/application/session_controller.dart';
import 'package:client/features/auth/data/models/user.dart';
import 'package:client/features/student/application/student_home_provider.dart';
import 'package:client/features/student/application/student_qr_controller.dart';
import 'package:client/features/student/data/student_qr_repository.dart';
import 'package:client/features/student/presentation/student_qr_screen.dart';
import 'package:client/features/student/presentation/student_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

const _user = User(
    id: 'sv1',
    code: 'SV001',
    email: 'huyen@example.edu.vn',
    fullName: 'Nguyễn Thị Huyền',
    role: UserRole.student,
    status: 'ACTIVE',
    mustChangePassword: false,
    faceEnrolled: false,
    version: 1);

class _Session extends SessionController {
  @override
  SessionState build() => const Authenticated(_user);
}

class _Repository implements StudentQrRepository {
  _Repository(this.load);
  final Future<StudentQrToken> Function() load;
  int calls = 0;
  @override
  Future<StudentQrToken> issue() {
    calls++;
    return load();
  }
}

final _start = DateTime.parse('2026-10-19T10:00:00+07:00');
DateTime _now = _start;
StudentQrToken _token([String value = 'server-qr-token']) => StudentQrToken(
    token: value,
    expiresAt: _now.add(const Duration(seconds: 30)),
    refreshAfterSeconds: 25);

Future<ProviderContainer> _pump(WidgetTester tester, _Repository repository,
    {Size size = const Size(390, 844), double scale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: Routes.studentQr, routes: [
    ShellRoute(builder: (_, __, child) => StudentShell(child: child), routes: [
      GoRoute(
          path: Routes.studentQr, builder: (_, __) => const StudentQrScreen()),
      GoRoute(
          path: Routes.studentHome,
          builder: (_, __) => const Text('Trang chủ sinh viên')),
    ]),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(_Session.new),
        studentQrRepositoryProvider.overrideWithValue(repository),
        studentClockProvider.overrideWithValue(() => _now),
      ],
      child: RepaintBoundary(
          key: const ValueKey('qr-preview'),
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
          ))));
  await tester.pump();
  return ProviderScope.containerOf(
      tester.element(find.byType(StudentQrScreen)));
}

void main() {
  setUp(() => _now = _start);
  setUpAll(() async {
    final fonts = FontLoader('BeVietnamPro');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/BeVietnamPro-$weight.ttf'));
    }
    await fonts.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  testWidgets(
      'renders the server token, student identity and absolute countdown',
      (tester) async {
    final repository = _Repository(() async => _token());
    final container = await _pump(tester, repository);
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(container.read(studentQrControllerProvider).code!.token,
        'server-qr-token');
    expect(find.text('Nguyễn Thị Huyền'), findsOneWidget);
    expect(find.text('SV001'), findsOneWidget);
    expect(find.text('Còn 30 giây'), findsOneWidget);
    _now = _now.add(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Còn 24 giây'), findsOneWidget);
    expect(repository.calls, 1);
    if (const bool.fromEnvironment('CAPTURE_STU02')) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('qr-preview')));
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/previews').create(recursive: true);
        await File('build/previews/stu-02.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'expiry removes scannable QR and only an explicit tap issues again',
      (tester) async {
    final repository = _Repository(() async => _token());
    await _pump(tester, repository);
    await tester.pumpAndSettle();
    _now = _now.add(const Duration(seconds: 31));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Mã đã hết hạn'), findsOneWidget);
    expect(repository.calls, 1);
    await tester.tap(find.text('Tạo mã mới'));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets(
      'slow requests block duplicate taps and leaving disposes the pending response',
      (tester) async {
    final pending = Completer<StudentQrToken>();
    final repository = _Repository(() => pending.future);
    final container = await _pump(tester, repository);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await container.read(studentQrControllerProvider.notifier).issue();
    expect(repository.calls, 1);
    await tester.tap(find.text('Trang chủ'));
    await tester.pumpAndSettle();
    pending.complete(_token());
    await tester.pumpAndSettle();
    expect(find.text('Trang chủ sinh viên'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('network error does not retry until the user requests a new code',
      (tester) async {
    var failed = true;
    final repository = _Repository(() async {
      if (failed) throw const ApiException(code: ClientErrorCode.network);
      return _token();
    });
    await _pump(tester, repository);
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Không tạo được mã QR'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(repository.calls, 1);
    failed = false;
    await tester.tap(find.text('Tạo mã mới'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(repository.calls, 2);
  });

  testWidgets('429 disables issuing until the retry deadline', (tester) async {
    final repository = _Repository(() async => throw const QrRateLimited(10));
    final container = await _pump(tester, repository);
    await tester.pumpAndSettle();
    expect(find.text('Thử lại sau 10 giây'), findsOneWidget);
    await container.read(studentQrControllerProvider.notifier).issue();
    expect(repository.calls, 1);
    _now = _now.add(const Duration(seconds: 11));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Tạo mã mới'));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
  });

  testWidgets(
      'background hides the QR and resume recalculates expiry without a POST',
      (tester) async {
    final repository = _Repository(() async => _token());
    await _pump(tester, repository);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);
    _now = _now.add(const Duration(minutes: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Mã đã hết hạn'), findsOneWidget);
    expect(repository.calls, 1);
  });

  testWidgets('narrow screen and large text fit without overflow',
      (tester) async {
    await _pump(tester, _Repository(() async => _token()),
        size: const Size(320, 640), scale: 1.5);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
