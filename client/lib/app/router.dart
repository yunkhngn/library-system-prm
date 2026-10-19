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
import '../features/student/presentation/student_home_screen.dart';
import '../features/student/presentation/student_shell.dart';
import '../features/student/presentation/student_qr_screen.dart';
import '../features/student/presentation/student_history_screen.dart';
import '../features/admin/presentation/accounts_screen.dart';
import '../features/admin/presentation/admin_overview_screen.dart';
import '../features/admin/presentation/analytics_screen.dart';
import '../features/admin/presentation/config_screen.dart';
import '../features/admin/presentation/kiosks_screen.dart';
import '../features/admin/presentation/shifts_screen.dart';
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
  final refresh =
      ValueNotifier<SessionState>(ref.read(sessionControllerProvider));
  ref.listen(sessionControllerProvider, (_, next) => refresh.value = next);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) =>
        _redirect(ref.read(sessionControllerProvider), state.uri.path),
    errorBuilder: (_, __) =>
        const SessionStatusScreen(variant: SessionStatusVariant.notFound),
    routes: [
      _route(Routes.splash, const SplashScreen()),
      _route(Routes.login, const LoginScreen()),
      _route(Routes.firstPasswordChange, const FirstPasswordChangeScreen()),
      _route(Routes.sessionExpired,
          const SessionStatusScreen(variant: SessionStatusVariant.expired)),
      _route(Routes.forbidden,
          const SessionStatusScreen(variant: SessionStatusVariant.forbidden)),
      if (kDebugMode)
        _route(Routes.componentGallery, const ComponentGalleryScreen()),

      ShellRoute(
        builder: (_, __, child) => StaffShell(child: child),
        routes: [
          // P5 — librarian.
          _route(Routes.librarianOverview, const DashboardScreen()),
          _route(Routes.myShifts, const MyShiftsScreen()),
          _route(Routes.libraryRules, const LibraryRulesScreen()),
          _route(Routes.occupants, const OccupantsScreen()),
          GoRoute(
            path: Routes.manualAccess,
            builder: (_, state) {
              final q = state.uri.queryParameters;
              return ManualAccessScreen(
                userId: q['userId'],
                visitorId: q['visitorId'],
                action: q['action'],
                code: q['code'],
                name: q['name'],
              );
            },
          ),
          _route(Routes.visitors, const VisitorsScreen()),
          GoRoute(
            path: '${Routes.visitors}/:visitorId',
            builder: (_, state) => VisitorDetailScreen(
                visitorId: state.pathParameters['visitorId']!),
          ),
          _route(Routes.accessHistory, const AccessHistoryScreen()),
          // P2 — staff account.
          _route(Routes.staffProfile, const StaffProfileScreen()),
          _route(Routes.changePassword, const ChangePasswordScreen()),
          // Administrator screens.
          _route(Routes.adminOverview, const AdminOverviewScreen()),
          _route(Routes.adminAccounts, const AccountsScreen()),
          _route(Routes.adminKiosks, const KiosksScreen()),
          _route(Routes.adminShifts, const ShiftsScreen()),
          _route(Routes.adminAnalytics, const AnalyticsScreen()),
          _route(Routes.adminConfig, const ConfigScreen()),
        ],
      ),

      // P3–P4 student and P10–P11 kiosk own their shells.
      ShellRoute(
        builder: (_, __, child) => StudentShell(child: child),
        routes: [
          _route(Routes.studentHome, const StudentHomeScreen()),
          _route(Routes.studentQr, const StudentQrScreen()),
          _route(Routes.studentHistory, const StudentHistoryScreen()),
          GoRoute(
              path: '${Routes.studentHistory}/:sessionId',
              builder: (_, __) => const PlaceholderPage(
                  screenId: 'STU-04', title: 'Chi tiết lượt ra vào')),
          _route(Routes.studentAccount,
              const PlaceholderPage(screenId: 'STU-05', title: 'Tài khoản')),
          _route(
              Routes.studentFace,
              const PlaceholderPage(
                  screenId: 'STU-06', title: 'Nhận diện khuôn mặt')),
        ],
      ),
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
      if (path.startsWith(Routes.kiosk) || path.startsWith('/dev/')) {
        return null;
      }
      if (user.mustChangePassword) {
        return path == Routes.firstPasswordChange
            ? null
            : Routes.firstPasswordChange;
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

GoRoute _route(String path, Widget screen) =>
    GoRoute(path: path, builder: (_, __) => screen);

class _Standalone extends StatelessWidget {
  const _Standalone(this.id, this.title);

  final String id;
  final String title;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: PlaceholderPage(screenId: id, title: title));
}
