import '../features/auth/data/models/user.dart';

/// Every route path lives here so features never hard-code strings.
abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const firstPasswordChange = '/first-password-change';
  static const sessionExpired = '/session-expired';
  static const forbidden = '/forbidden';
  static const componentGallery = '/dev/components';

  // Librarian only.
  static const librarianOverview = '/librarian/overview';
  static const myShifts = '/librarian/shifts';
  static const libraryRules = '/librarian/rules';

  // Operational screens shared by librarians and administrators.
  static const occupants = '/staff/occupants';
  static const manualAccess = '/staff/manual-access';
  static String manualAccessFor({
    String? userId,
    String? visitorId,
    String? action,
    String? code,
    String? name,
  }) {
    final params = <String, String>{
      if (userId != null) 'userId': userId,
      if (visitorId != null) 'visitorId': visitorId,
      if (action != null) 'action': action,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
    };
    if (params.isEmpty) return manualAccess;
    return Uri(path: manualAccess, queryParameters: params).toString();
  }
  static const visitors = '/staff/visitors';
  static String visitorDetail(String id) => '/staff/visitors/$id';
  static const accessHistory = '/staff/history';
  static const staffProfile = '/staff/profile';
  static const changePassword = '/staff/change-password';

  // Administrator only (P6–P9).
  static const adminOverview = '/admin/overview';
  static const adminAccounts = '/admin/accounts';
  static const adminKiosks = '/admin/kiosks';
  static const adminShifts = '/admin/shifts';
  static const adminAnalytics = '/admin/analytics';
  static const adminConfig = '/admin/config';

  // Student (P3–P4) and kiosk (P10–P11).
  static const studentHome = '/student/home';
  static const kiosk = '/kiosk';

  static String homeFor(UserRole role) => switch (role) {
        UserRole.student => studentHome,
        UserRole.librarian => librarianOverview,
        UserRole.admin => adminOverview,
      };

  /// Reachable without a user session. Kiosks authenticate as devices.
  static bool isPublic(String path) =>
      path == login ||
      path == sessionExpired ||
      path.startsWith(kiosk) ||
      path.startsWith('/dev/');
}
