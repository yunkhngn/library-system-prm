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
                    _TopBar(
                      user: user,
                      showMenuButton: !wide,
                      compact: constraints.maxWidth < AppSizes.compactBreakpoint,
                    ),
                    Expanded(child: SafeArea(top: false, child: child)),
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
    return Material(
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
  const _TopBar({required this.user, required this.showMenuButton, required this.compact});

  final User user;
  final bool showMenuButton;

  /// Phone widths: only the avatar is shown, the name moves into the menu.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 64,
          padding: EdgeInsets.symmetric(horizontal: compact ? AppSpacing.sm : AppSpacing.lg),
          child: _buildRow(context, ref),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, WidgetRef ref) {
    return Row(
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
          itemBuilder: (_) => [
            if (compact) ...[
              PopupMenuItem(
                enabled: false,
                child: _UserLabel(user: user),
              ),
              const PopupMenuDivider(),
            ],
            const PopupMenuItem(value: 'profile', child: Text('Hồ sơ tài khoản')),
            const PopupMenuItem(value: 'password', child: Text('Đổi mật khẩu')),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'logout', child: Text('Đăng xuất')),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.navy,
                  child: Text(user.initials,
                      style: AppTypography.caption.copyWith(color: Colors.white)),
                ),
                if (!compact) ...[
                  const SizedBox(width: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: _UserLabel(user: user),
                  ),
                ],
                const Icon(Icons.expand_more, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _UserLabel extends StatelessWidget {
  const _UserLabel({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          user.fullName,
          style: AppTypography.label.copyWith(color: AppColors.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          user.role.label,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
