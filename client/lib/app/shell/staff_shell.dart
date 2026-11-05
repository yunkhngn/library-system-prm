import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/theme_toggle_button.dart';
import '../../features/auth/application/session_controller.dart';
import '../../features/auth/data/models/user.dart';
import '../../features/auth/presentation/logout_dialog.dart';
import '../routes.dart';
import 'staff_nav.dart';

class StaffShell extends ConsumerWidget {
  const StaffShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    if (session is! Authenticated) return const SizedBox.shrink();
    final location = GoRouterState.of(context).uri.path;
    final items = staffNavFor(session.user.role);
    final sidebar = _Sidebar(items: items, location: location);

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= AppSizes.desktopBreakpoint;
      return Scaffold(
        drawer:
            wide ? null : Drawer(width: AppSizes.sidebarWidth, child: sidebar),
        body: Row(children: [
          if (wide) SizedBox(width: AppSizes.sidebarWidth, child: sidebar),
          Expanded(
            child: Column(children: [
              _TopBar(
                user: session.user,
                title: _titleFor(items, location),
                showMenuButton: !wide,
                compact: constraints.maxWidth < AppSizes.compactBreakpoint,
              ),
              Expanded(child: SafeArea(top: false, child: child)),
            ]),
          ),
        ]),
      );
    });
  }

  String _titleFor(List<StaffNavItem> items, String location) {
    for (final item in items) {
      if (location.startsWith(item.route)) return item.label;
    }
    return 'Library Access';
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.items, required this.location});

  final List<StaffNavItem> items;
  final String location;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.sidebar,
        child: SafeArea(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 12, 22),
              child: Row(children: [
                const Icon(Icons.stop_circle_outlined,
                    size: 15, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Library Access',
                  style: AppTypography.h3.copyWith(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (items.length > 8 && i == 5) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
                        child: Text(
                          'Quản trị',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.sidebarMuted),
                        ),
                      ),
                    ],
                    _NavTile(
                        item: items[i],
                        selected: location.startsWith(items[i].route)),
                  ],
                ],
              ),
            ),
          ]),
        ),
      );
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.selected});
  final StaffNavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: SizedBox(
          height: 40,
          child: ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            horizontalTitleGap: 12,
            minLeadingWidth: 18,
            selected: selected,
            selectedTileColor: AppColors.sidebarSelected,
            shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.controlBorder),
            leading: Icon(item.icon, size: 18, color: Colors.white),
            title: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: Colors.white,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            onTap: () {
              Scaffold.maybeOf(context)?.closeDrawer();
              context.go(item.route);
            },
          ),
        ),
      );
}

class _TopBar extends ConsumerWidget {
  const _TopBar(
      {required this.user,
      required this.title,
      required this.showMenuButton,
      required this.compact});

  final User user;
  final String title;
  final bool showMenuButton;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 28),
              child: Row(children: [
                if (showMenuButton)
                  IconButton(
                    tooltip: 'Mở menu',
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                if (!compact)
                  Text(title, style: AppTypography.h3.copyWith(fontSize: 20)),
                const Spacer(),
                const ThemeToggleButton(),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Tài khoản',
                  position: PopupMenuPosition.under,
                  onSelected: (value) {
                    if (value == 'profile') context.go(Routes.staffProfile);
                    if (value == 'password') context.go(Routes.changePassword);
                    if (value == 'logout') confirmLogout(context, ref);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'profile', child: Text('Hồ sơ tài khoản')),
                    PopupMenuItem(
                        value: 'password', child: Text('Đổi mật khẩu')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'logout', child: Text('Đăng xuất')),
                  ],
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: AppColors.infoSurface,
                      child: Text(user.initials,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.navy)),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${user.fullName} · ${user.role.label}',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
}
