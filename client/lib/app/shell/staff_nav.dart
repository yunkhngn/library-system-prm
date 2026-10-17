import 'package:flutter/material.dart';

import '../../features/auth/data/models/user.dart';
import '../routes.dart';

class StaffNavItem {
  const StaffNavItem(this.label, this.icon, this.route);

  final String label;
  final IconData icon;
  final String route;
}

/// Sidebar order from DESIGN_SYSTEM.md section 4.
List<StaffNavItem> staffNavFor(UserRole role) {
  const shared = [
    StaffNavItem('Người đang trong thư viện', Icons.groups_outlined, Routes.occupants),
    StaffNavItem('Ghi nhận thủ công', Icons.edit_note_outlined, Routes.manualAccess),
    StaffNavItem('Khách ngoài', Icons.badge_outlined, Routes.visitors),
    StaffNavItem('Lịch sử ra vào', Icons.history, Routes.accessHistory),
  ];

  return switch (role) {
    UserRole.librarian => const [
        StaffNavItem('Tổng quan', Icons.dashboard_outlined, Routes.librarianOverview),
        ...shared,
        StaffNavItem('Ca trực của tôi', Icons.event_outlined, Routes.myShifts),
        StaffNavItem('Quy định thư viện', Icons.rule_outlined, Routes.libraryRules),
      ],
    UserRole.admin => const [
        StaffNavItem('Tổng quan', Icons.dashboard_outlined, Routes.adminOverview),
        ...shared,
        StaffNavItem('Tài khoản', Icons.manage_accounts_outlined, Routes.adminAccounts),
        StaffNavItem('Thiết bị Kiosk', Icons.tablet_mac_outlined, Routes.adminKiosks),
        StaffNavItem('Phân ca nhân viên', Icons.calendar_month_outlined, Routes.adminShifts),
        StaffNavItem('Thống kê', Icons.bar_chart_outlined, Routes.adminAnalytics),
        StaffNavItem('Cấu hình hệ thống', Icons.settings_outlined, Routes.adminConfig),
      ],
    UserRole.student => const [],
  };
}
