import 'dart:io';
import 'dart:ui' as ui;

import 'package:client/app/routes.dart';
import 'package:client/core/network/api_error.dart';
import 'package:client/core/storage/token_storage.dart';
import 'package:client/core/theme/app_theme.dart';
import 'package:client/features/auth/application/session_controller.dart';
import 'package:client/features/auth/data/auth_repository.dart';
import 'package:client/features/auth/data/models/token_pair.dart';
import 'package:client/features/auth/data/models/user.dart';
import 'package:client/features/student/presentation/student_account_screen.dart';
import 'package:client/features/student/presentation/student_change_password_screen.dart';
import 'package:client/features/student/presentation/student_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

User _user({bool enrolled = false, String name = 'Nguyễn Thị Huyền'}) => User(
    id: 'sv1',
    code: 'SV001',
    email: 'huyen.nt@sv.example.edu.vn',
    fullName: name,
    role: UserRole.student,
    status: 'ACTIVE',
    mustChangePassword: false,
    faceEnrolled: enrolled,
    version: 1);

class _Session extends SessionController {
  @override
  SessionState build() => Authenticated(_user());
}

class _Tokens extends TokenStorage {
  String? refreshToken = 'old-refresh';
  @override
  Future<String?> readRefreshToken() async => refreshToken;
  @override
  Future<void> save(
      {required String accessToken, required String refreshToken}) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
  }
}

class _Auth implements AuthRepository {
  User user = _user();
  ApiException? error;
  String? newPassword;
  String? currentPassword;
  int logoutCalls = 0;
  @override
  Future<User> me() async {
    if (error != null) throw error!;
    return user;
  }

  @override
  Future<void> logout(String token) async {
    logoutCalls++;
  }

  @override
  Future<TokenPair> changePassword(
      {required String currentPassword, required String newPassword}) async {
    this.currentPassword = currentPassword;
    this.newPassword = newPassword;
    return TokenPair(
        accessToken: 'new-access',
        refreshToken: 'new-refresh',
        expiresIn: const Duration(minutes: 15),
        user: user);
  }

  @override
  Future<TokenPair> login(
          {required String identifier, required String password}) =>
      throw UnimplementedError();
  @override
  Future<TokenPair> refresh(String token) => throw UnimplementedError();
}

Future<ProviderContainer> _pump(WidgetTester tester, _Auth auth, _Tokens tokens,
    {Size size = const Size(390, 844), double scale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: Routes.studentAccount, routes: [
    ShellRoute(builder: (_, __, child) => StudentShell(child: child), routes: [
      GoRoute(
          path: Routes.studentAccount,
          builder: (_, __) => const StudentAccountScreen()),
      GoRoute(
          path: Routes.studentChangePassword,
          builder: (_, __) => const StudentChangePasswordScreen()),
      GoRoute(
          path: Routes.studentFace,
          builder: (_, __) => const Text('Quản lý khuôn mặt')),
    ]),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(_Session.new),
        authRepositoryProvider.overrideWithValue(auth),
        tokenStorageProvider.overrideWithValue(tokens),
      ],
      child: RepaintBoundary(
          key: const ValueKey('preview'),
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
          ))));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(StudentShell)));
}

void main() {
  setUpAll(() async {
    final font = FontLoader('BeVietnamPro');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      font.addFont(rootBundle.load('assets/fonts/BeVietnamPro-$weight.ttf'));
    }
    await font.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  testWidgets('STU-05 shows read-only current profile', (tester) async {
    await _pump(tester, _Auth(), _Tokens());
    expect(find.text('NH'), findsOneWidget);
    expect(find.text('Nguyễn Thị Huyền'), findsOneWidget);
    expect(find.text('SV001 · Sinh viên'), findsOneWidget);
    expect(find.text('huyen.nt@sv.example.edu.vn'), findsOneWidget);
    expect(find.text('Chưa đăng ký'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    if (const bool.fromEnvironment('CAPTURE_STU05')) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('preview')));
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/previews').create(recursive: true);
        await File('build/previews/stu-05.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });

  testWidgets('fresh enrollment is shown instead of the old session value',
      (tester) async {
    await _pump(tester, _Auth()..user = _user(enrolled: true), _Tokens());
    expect(find.text('Đã đăng ký'), findsOneWidget);
    await tester.tap(find.text('Nhận diện khuôn mặt'));
    await tester.pumpAndSettle();
    expect(find.text('Quản lý khuôn mặt'), findsOneWidget);
  });

  testWidgets(
      'profile failure has a retry and does not claim enrollment status',
      (tester) async {
    final auth = _Auth()
      ..error = const ApiException(code: ClientErrorCode.network);
    await _pump(tester, auth, _Tokens());
    expect(find.text('Không tải được dữ liệu'), findsOneWidget);
    expect(find.text('Chưa đăng ký'), findsNothing);
    auth.error = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn Thị Huyền'), findsOneWidget);
  });

  testWidgets(
      'student password form validates, rotates tokens and returns to account',
      (tester) async {
    final auth = _Auth();
    final tokens = _Tokens();
    await _pump(tester, auth, tokens);
    await tester.tap(find.text('Bảo mật'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(0), 'OldValid!2026Secret');
    await tester.enterText(fields.at(1), 'NewValid!2026Secret');
    await tester.enterText(fields.at(2), 'NewValid!2026Secret');
    final submit = find.widgetWithText(TextButton, 'Đổi mật khẩu');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(auth.currentPassword, 'OldValid!2026Secret');
    expect(auth.newPassword, 'NewValid!2026Secret');
    expect(tokens.accessToken, 'new-access');
    expect(tokens.refreshToken, 'new-refresh');
    expect(find.text('Nguyễn Thị Huyền'), findsOneWidget);
    expect(find.text('Đã đổi mật khẩu thành công.'), findsOneWidget);
  });

  testWidgets('logout requires confirmation and clears the session',
      (tester) async {
    final auth = _Auth();
    final tokens = _Tokens();
    final container = await _pump(tester, auth, tokens);
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(auth.logoutCalls, 0);
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Đăng xuất').last);
    await tester.pumpAndSettle();
    expect(auth.logoutCalls, 1);
    expect(tokens.refreshToken, isNull);
    expect(container.read(sessionControllerProvider), isA<SignedOut>());
  });

  testWidgets('long names and larger text do not overflow on a small screen',
      (tester) async {
    await _pump(
        tester,
        _Auth()..user = _user(name: 'Nguyễn Thị Huyền Phương Minh Anh'),
        _Tokens(),
        size: const Size(320, 640),
        scale: 1.5);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
