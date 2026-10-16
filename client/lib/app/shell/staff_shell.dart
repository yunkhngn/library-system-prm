import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../features/auth/application/session_controller.dart';
import '../../features/auth/data/models/user.dart';
import '../../features/auth/presentation/logout_dialog.dart';
import '../routes.dart';
import 'staff_nav.dart';

/// Desktop shell for librarians and administrators: navy sidebar + top bar.
/// Below [AppSizes.desktopBreakpoint] the sidebar moves into a drawer.
class StaffShell extends ConsumerWidget {
  const StaffShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    if (session is! Authenticated) return const SizedBox.shrink();

    final user = session.user;
    final location = GoRouterState.of(context).uri.path;
    final sidebar = _Sidebar(items: staffNavFor(user.role), location: location);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AppSizes.desktopBreakpoint;
        return Scaffold(
          drawer: wide ? null : Drawer(width: AppSizes.sidebarWidth, child: sidebar),
          body: Row(
            children: [
              if (wide) SizedBox(width: AppSizes.sidebarWidth, child: sidebar),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(user: user, showMenuButton: !wide),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.items, required this.location});

  final List<StaffNavItem> items;
  final String location;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.navy,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Library Access', style: AppTypography.h3.copyWith(color: Colors.white)),
                  Text(
                    'Hệ thống ghi nhận ra vào thư viện',
                    style: AppTypography.caption.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final item in items)
                    _NavTile(item: item, selected: location.startsWith(item.route)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.selected});

  final StaffNavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        dense: true,
        selected: selected,
        selectedTileColor: Colors.white.withValues(alpha: 0.12),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.controlBorder),
        leading: Icon(item.icon, size: 20, color: selected ? Colors.white : Colors.white70),
        title: Text(
          item.label,
          style: AppTypography.label.copyWith(color: selected ? Colors.white : Colors.white70),
        ),
        onTap: () {
          Scaffold.maybeOf(context)?.closeDrawer();
          context.go(item.route);
        },
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.user, required this.showMenuButton});

  final User user;
  final bool showMenuButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (showMenuButton)
            IconButton(
              tooltip: 'Mở menu',
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: 'Tài khoản',
            position: PopupMenuPosition.under,
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  context.go(Routes.staffProfile);
                case 'password':
                  context.go(Routes.changePassword);
                default:
                  confirmLogout(context, ref);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'profile', child: Text('Hồ sơ tài khoản')),
              PopupMenuItem(value: 'password', child: Text('Đổi mật khẩu')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: Text('Đăng xuất')),
            ],
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.navy,
                  child: Text(user.initials, style: AppTypography.caption.copyWith(color: Colors.white)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName, style: AppTypography.label),
                    Text(user.role.label, style: AppTypography.caption),
                  ],
                ),
                const Icon(Icons.expand_more, color: AppColors.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
