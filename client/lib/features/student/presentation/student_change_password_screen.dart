import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../auth/presentation/widgets/change_password_form.dart';
import '../application/student_account_provider.dart';

/// Student wrapper; the existing AUTH password form retains validation and token rotation.
class StudentChangePasswordScreen extends ConsumerWidget {
  const StudentChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const Text('Đổi mật khẩu', style: AppTypography.h2),
          const SizedBox(height: AppSpacing.lg),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: ChangePasswordForm(onSuccess: () {
                    if (!context.mounted) return;
                    ref.invalidate(studentAccountProvider);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Đã đổi mật khẩu thành công.')));
                    context.go(Routes.studentAccount);
                  }))),
          const SizedBox(height: AppSpacing.md),
          Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                  label: 'Quay lại tài khoản',
                  variant: AppButtonVariant.link,
                  onPressed: () => context.go(Routes.studentAccount))),
        ],
      );
}
