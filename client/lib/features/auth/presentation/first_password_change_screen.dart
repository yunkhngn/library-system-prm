import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../application/session_controller.dart';
import 'widgets/auth_card.dart';
import 'widgets/change_password_form.dart';

/// AUTH-02 — Required first password change. The router keeps the user here
/// until `mustChangePassword` becomes false; the only exit is logging out.
class FirstPasswordChangeScreen extends ConsumerWidget {
  const FirstPasswordChangeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuthCard(
      title: 'Đổi mật khẩu lần đầu',
      subtitle: 'Mật khẩu ban đầu do quản trị viên cấp. Bạn cần đổi mật khẩu trước khi sử dụng hệ thống.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ChangePasswordForm(),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Đăng xuất',
            variant: AppButtonVariant.ghost,
            onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
