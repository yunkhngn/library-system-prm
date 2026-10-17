import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'widgets/change_password_form.dart';

/// AUTH-03 — Change password from the profile menu.
class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Đổi mật khẩu', style: AppTypography.h1),
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: ChangePasswordForm(
                    onSuccess: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã đổi mật khẩu thành công.')),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
