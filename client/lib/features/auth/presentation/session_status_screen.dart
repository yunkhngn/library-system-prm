import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../shared/widgets/app_button.dart';
import '../application/session_controller.dart';
import 'widgets/auth_card.dart';

enum SessionStatusVariant { expired, forbidden, notFound }

/// AUTH-05 — Session expired / access denied / missing resource.
/// Rendered outside the shell so no protected data stays visible.
class SessionStatusScreen extends ConsumerWidget {
  const SessionStatusScreen({super.key, required this.variant});

  final SessionStatusVariant variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (title, message) = switch (variant) {
      SessionStatusVariant.expired => (
          'Phiên đăng nhập đã hết hạn',
          'Vì lý do bảo mật, vui lòng đăng nhập lại để tiếp tục.',
        ),
      SessionStatusVariant.forbidden => (
          'Không có quyền truy cập',
          'Tài khoản của bạn không được phép xem trang này.',
        ),
      SessionStatusVariant.notFound => (
          'Không tìm thấy trang',
          'Trang bạn tìm không tồn tại hoặc đã bị thay đổi.',
        ),
    };

    final session = ref.watch(sessionControllerProvider);
    final action = switch (session) {
      Authenticated(:final user) => AppButton(
          label: 'Về trang chủ',
          expand: true,
          onPressed: () => context.go(Routes.homeFor(user.role)),
        ),
      _ => AppButton(
          label: 'Đăng nhập lại',
          expand: true,
          onPressed: () => context.go(Routes.login),
        ),
    };

    return AuthCard(title: title, subtitle: message, child: action);
  }
}
