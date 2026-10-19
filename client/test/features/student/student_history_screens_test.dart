import 'dart:io';
import 'dart:ui' as ui;

import 'package:client/app/routes.dart';
import 'package:client/core/network/api_error.dart';
import 'package:client/core/network/paged.dart';
import 'package:client/core/theme/app_theme.dart';
import 'package:client/features/access/data/models/access_session.dart';
import 'package:client/features/auth/application/session_controller.dart';
import 'package:client/features/auth/data/models/user.dart';
import 'package:client/features/student/application/student_history_providers.dart';
import 'package:client/features/student/application/student_home_provider.dart';
import 'package:client/features/student/data/student_history_repository.dart';
import 'package:client/features/student/presentation/student_history_screen.dart';
import 'package:client/features/student/presentation/student_session_detail_screen.dart';
import 'package:client/features/student/presentation/student_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _user = User(
    id: 'sv1',
    code: 'SV001',
    email: 'sv@example.edu.vn',
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

final _now = DateTime.parse('2026-10-13T14:25:00+07:00');

AccessSession _visit(String id, String entry, {String? exit, String? reason}) =>
    AccessSession.fromJson({
      'id': id,
      'subject': {
        'id': 'sv1',
        'kind': 'USER',
        'code': 'SV001',
        'fullName': _user.fullName
      },
      'checkInTime': entry, 'checkOutTime': exit,
      'checkInMethod': 'FACE',
      'checkOutMethod': reason == null ? 'MANUAL' : null,
      'checkInKiosk': {
        'id': 'k1',
        'code': 'K1',
        'name': 'Cổng chính – Lối vào'
      },
      // Deliberately inconsistent actor on auto-close: the screen must never invent/show it.
      'checkOutBy': {
        'id': 'lib1',
        'code': 'LIB001',
        'fullName': 'Lê Thu Trang'
      },
      'checkoutReason': reason,
      'durationSeconds': exit == null
          ? 4800
          : DateTime.parse(exit).difference(DateTime.parse(entry)).inSeconds,
    });
final _visits = [
  _visit('open', '2026-10-13T13:05:00+07:00'),
  _visit('closed', '2026-10-12T08:15:00+07:00',
      exit: '2026-10-12T11:40:00+07:00'),
  _visit('third', '2026-10-10T09:02:00+07:00',
      exit: '2026-10-10T12:10:00+07:00'),
  _visit('fourth', '2026-10-09T08:30:00+07:00',
      exit: '2026-10-09T10:05:00+07:00'),
];

class _History implements StudentHistoryRepository {
  List<AccessSession> items = _visits;
  int totalPages = 1;
  Object? error;
  int requests = 0;
  int? requestedPage;
  String? requestedId;
  DateTime? from;
  DateTime? to;
  AccessSession? detailResult;
  @override
  Future<Paged<AccessSession>> list(
      {required DateTime from, required DateTime to, int page = 0}) async {
    requests++;
    requestedPage = page;
    this.from = from;
    this.to = to;
    if (error != null) throw error!;
    return Paged(
        items: items,
        page: page,
        size: 20,
        totalElements: totalPages == 1 ? items.length : 25,
        totalPages: totalPages);
  }

  @override
  Future<AccessSession> detail(String sessionId) async {
    requestedId = sessionId;
    if (error != null) throw error!;
    return detailResult ??
        items.firstWhere((session) => session.id == sessionId);
  }
}

Future<ProviderContainer> _pump(WidgetTester tester, _History repository,
    {String? location,
    Size size = const Size(390, 844),
    double scale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router =
      GoRouter(initialLocation: location ?? Routes.studentHistory, routes: [
    ShellRoute(builder: (_, __, child) => StudentShell(child: child), routes: [
      GoRoute(
          path: Routes.studentHistory,
          builder: (_, __) => const StudentHistoryScreen()),
      GoRoute(
          path: '${Routes.studentHistory}/:sessionId',
          builder: (_, state) => StudentSessionDetailScreen(
              sessionId: state.pathParameters['sessionId']!)),
    ]),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(_Session.new),
        studentHistoryRepositoryProvider.overrideWithValue(repository),
        studentClockProvider.overrideWithValue(() => _now),
      ],
      child: RepaintBoundary(
          key: const ValueKey('preview'),
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            routerConfig: router,
            locale: const Locale('vi', 'VN'),
            supportedLocales: const [Locale('vi', 'VN')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
          ))));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(StudentShell)));
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_STU_HISTORY')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('preview')));
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/previews').create(recursive: true);
    await File('build/previews/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
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

  testWidgets('STU-03 defaults to 30 days and opens STU-04 with manual actor',
      (tester) async {
    final repository = _History();
    await _pump(tester, repository);
    expect(repository.from, _now.subtract(const Duration(days: 30)));
    expect(repository.to, _now);
    expect(find.text('Đang trong thư viện'), findsOneWidget);
    expect(find.text('3 giờ 25 phút'), findsOneWidget);
    await _capture(tester, 'stu-03');
    await tester.tap(find.text('3 giờ 25 phút'));
    await tester.pumpAndSettle();
    expect(repository.requestedId, 'closed');
    expect(find.text('Ghi nhận vào'), findsOneWidget);
    expect(find.text('Ghi nhận ra'), findsOneWidget);
    expect(find.text('08:15 · Khuôn mặt'), findsOneWidget);
    expect(find.text('11:40 · Thủ công'), findsOneWidget);
    expect(find.text('Nhân viên: Lê Thu Trang'), findsOneWidget);
    await _capture(tester, 'stu-04');
  });

  testWidgets(
      'pagination and range changes reset page and preserve state after detail',
      (tester) async {
    final repository = _History()..totalPages = 2;
    final container = await _pump(tester, repository);
    await tester.ensureVisible(find.text('Trang sau'));
    await tester.tap(find.text('Trang sau'));
    await tester.pumpAndSettle();
    expect(repository.requestedPage, 1);
    await tester.drag(find.byType(ListView), const Offset(0, 900));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Lọc khoảng thời gian'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7 ngày qua').last);
    await tester.pumpAndSettle();
    expect(repository.requestedPage, 0);
    expect(repository.from, _now.subtract(const Duration(days: 7)));
    await tester.tap(find.text('3 giờ 25 phút'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Quay lại lịch sử'));
    await tester.tap(find.text('Quay lại lịch sử'));
    await tester.pumpAndSettle();
    expect(container.read(studentHistoryQueryProvider).range,
        StudentHistoryRange.week);
  });

  testWidgets('empty history and network retry show honest states',
      (tester) async {
    final repository = _History()
      ..error = const ApiException(code: ClientErrorCode.network);
    await _pump(tester, repository);
    expect(find.text('Không tải được dữ liệu'), findsOneWidget);
    expect(find.text('Chưa có lượt ra vào'), findsNothing);
    repository.error = null;
    repository.items = [];
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có lượt ra vào'), findsOneWidget);
  });

  testWidgets(
      'custom range is UTC+7 exclusive end and rejects more than 366 days',
      (tester) async {
    final repository = _History();
    final container = await _pump(tester, repository);
    final controller = container.read(studentHistoryQueryProvider.notifier);
    final from = DateTime.parse('2026-10-01T00:00:00+07:00');
    final to = DateTime.parse('2026-10-14T00:00:00+07:00');
    controller.setRange(from, to);
    await tester.pumpAndSettle();
    expect(repository.from, DateTime.utc(2026, 9, 30, 17));
    expect(repository.to, DateTime.utc(2026, 10, 13, 17));
    expect(find.text('01/10/2026 – 13/10/2026'), findsOneWidget);
    expect(() => controller.setRange(from, from.add(const Duration(days: 367))),
        throwsArgumentError);
  });

  testWidgets('open session shows no fabricated exit', (tester) async {
    await _pump(tester, _History(),
        location: Routes.studentHistoryDetail('open'));
    expect(find.text('Đang trong thư viện'), findsOneWidget);
    expect(find.text('Đã ở 1 giờ 20 phút'), findsOneWidget);
    expect(find.text('Chưa ghi nhận ra'), findsOneWidget);
    expect(find.text('Ghi nhận ra'), findsNothing);
    expect(find.text('Nhân viên: Lê Thu Trang'), findsNothing);
  });

  for (final reason in ['CLOSING_TIME', 'MAX_DURATION']) {
    testWidgets(
        'automatic closure $reason explains reason without a staff actor',
        (tester) async {
      final repository = _History()
        ..detailResult = _visit('auto', '2026-10-12T08:00:00+07:00',
            exit: '2026-10-12T18:00:00+07:00', reason: reason);
      await _pump(tester, repository,
          location: Routes.studentHistoryDetail('auto'));
      expect(find.text('Đóng lượt tự động'), findsOneWidget);
      expect(
          find.textContaining(
              reason == 'CLOSING_TIME' ? 'giờ đóng cửa' : 'lưu lại tối đa'),
          findsOneWidget);
      expect(find.text('Nhân viên: Lê Thu Trang'), findsNothing);
    });
  }

  testWidgets('404 detail does not disclose another student and offers return',
      (tester) async {
    final repository = _History()
      ..error = const ApiException(code: 'NOT_FOUND', statusCode: 404);
    await _pump(tester, repository,
        location: Routes.studentHistoryDetail('other'));
    expect(find.text('Không tìm thấy lượt ra vào'), findsOneWidget);
    expect(find.text('Ghi nhận vào'), findsNothing);
    expect(find.text('Quay lại lịch sử'), findsOneWidget);
  });

  for (final location in [
    Routes.studentHistory,
    Routes.studentHistoryDetail('closed')
  ]) {
    testWidgets('narrow large-text layout does not overflow at $location',
        (tester) async {
      await _pump(tester, _History(),
          location: location, size: const Size(320, 640), scale: 1.5);
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
