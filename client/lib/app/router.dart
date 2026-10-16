import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/session_controller.dart';
import '../features/auth/data/models/user.dart';
import '../features/auth/presentation/change_password_screen.dart';
import '../features/auth/presentation/first_password_change_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/session_status_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/presentation/staff_profile_screen.dart';
import '../features/dev/component_gallery_screen.dart';
import '../features/librarian/access_history/presentation/access_history_screen.dart';
import '../features/librarian/dashboard/presentation/dashboard_screen.dart';
import '../features/librarian/library_rules/presentation/library_rules_screen.dart';
import '../features/librarian/manual_access/presentation/manual_access_screen.dart';
import '../features/librarian/my_shifts/presentation/my_shifts_screen.dart';
import '../features/librarian/occupants/presentation/occupants_screen.dart';
import '../features/librarian/visitors/presentation/visitor_detail_screen.dart';
import '../features/librarian/visitors/presentation/visitors_screen.dart';
import '../shared/widgets/placeholder_page.dart';
import 'routes.dart';
import 'shell/staff_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<SessionState>(ref.read(sessionControllerProvider));
  ref.listen(sessionControllerProvider, (_, next) => refresh.value = next);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref.read(sessionControllerProvider), state.uri.path),
    errorBuilder: (_, __) => const SessionStatusScreen(variant: SessionStatusVariant.notFound),
    routes: [
      _route(Routes.splash, const SplashScreen()),
      _route(Routes.login, const LoginScreen()),
      _route(Routes.firstPasswordChange, const FirstPasswordChangeScreen()),
      _route(Routes.sessionExpired, const SessionStatusScreen(variant: SessionStatusVariant.expired)),
      _route(Routes.forbidden, const SessionStatusScreen(variant: SessionStatusVariant.forbidden)),
      if (kDebugMode) _route(Routes.componentGallery, const ComponentGalleryScreen()),

      ShellRoute(
        builder: (_, __, child) => StaffShell(child: child),
        routes: [
          // P5 — librarian.
          _route(Routes.librarianOverview, const DashboardScreen()),
          _route(Routes.myShifts, const MyShiftsScreen()),
          _route(Routes.libraryRules, const LibraryRulesScreen()),
          _route(Routes.occupants, const OccupantsScreen()),
          _route(Routes.manualAccess, const ManualAccessScreen()),
          _route(Routes.visitors, const VisitorsScreen()),
          GoRoute(
            path: '${Routes.visitors}/:visitorId',
            builder: (_, state) => VisitorDetailScreen(visitorId: state.pathParameters['visitorId']!),
          ),
          _route(Routes.accessHistory, const AccessHistoryScreen()),
          // P2 — staff account.
          _route(Routes.staffProfile, const StaffProfileScreen()),
          _route(Routes.changePassword, const ChangePasswordScreen()),
          // P6–P9 — administrator; replace placeholders when implemented.
          _placeholder(Routes.adminOverview, 'ADM-01', 'Tổng quan'),
          _placeholder(Routes.adminAccounts, 'ADM-02', 'Tài khoản'),
          _placeholder(Routes.adminKiosks, 'ADM-07', 'Thiết bị Kiosk'),
          _placeholder(Routes.adminShifts, 'ADM-11', 'Phân ca nhân viên'),
          _placeholder(Routes.adminAnalytics, 'ADM-15', 'Thống kê'),
          _placeholder(Routes.adminConfig, 'ADM-17', 'Cấu hình hệ thống'),
        ],
      ),

      // P3–P4 student and P10–P11 kiosk own their shells.
      _route(Routes.studentHome, const _Standalone('STU-01', 'Trang chủ')),
      _route(Routes.kiosk, const _Standalone('KSK-02', 'Kiosk sẵn sàng')),
    ],
  );
});

String? _redirect(SessionState session, String path) {
  switch (session) {
    case SessionRestoring():
      return path == Routes.splash ? null : Routes.splash;

    case SignedOut(:final expired):
      if (Routes.isPublic(path)) return null;
      return expired ? Routes.sessionExpired : Routes.login;

    case Authenticated(:final user):
      if (path.startsWith(Routes.kiosk) || path.startsWith('/dev/')) return null;
      if (user.mustChangePassword) {
        return path == Routes.firstPasswordChange ? null : Routes.firstPasswordChange;
      }
      const entryPaths = {
        '/',
        Routes.splash,
        Routes.login,
        Routes.firstPasswordChange,
        Routes.sessionExpired,
      };
      if (entryPaths.contains(path)) return Routes.homeFor(user.role);
      return _canAccess(user.role, path) ? null : Routes.forbidden;
  }
}

bool _canAccess(UserRole role, String path) {
  if (path.startsWith('/admin/')) return role == UserRole.admin;
  if (path.startsWith('/librarian/')) return role == UserRole.librarian;
  if (path.startsWith('/staff/')) return role.isStaff;
  if (path.startsWith('/student/')) return role == UserRole.student;
  return true;
}

GoRoute _route(String path, Widget screen) => GoRoute(path: path, builder: (_, __) => screen);

GoRoute _placeholder(String path, String id, String title) =>
    _route(path, PlaceholderPage(screenId: id, title: title));

class _Standalone extends StatelessWidget {
  const _Standalone(this.id, this.title);

  final String id;
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(body: PlaceholderPage(screenId: id, title: title));
}
