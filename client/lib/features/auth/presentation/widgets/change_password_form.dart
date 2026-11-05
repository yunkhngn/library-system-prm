import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_alert.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../application/password_policy.dart';
import '../../application/session_controller.dart';
import 'password_strength_meter.dart';

/// Shared by AUTH-02 (required first change) and AUTH-03 (voluntary change).
class ChangePasswordForm extends ConsumerStatefulWidget {
  const ChangePasswordForm({super.key, this.onSuccess});

  final VoidCallback? onSuccess;

  @override
  ConsumerState<ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends ConsumerState<ChangePasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitting = false;
  ApiException? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(sessionControllerProvider.notifier).changePassword(
            currentPassword: _current.text,
            newPassword: _new.text,
          );
      widget.onSuccess?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isOutcomeUncertain) {
        // The password may already have changed; resubmitting would fail with
        // CURRENT_PASSWORD_INVALID. Ask the user to sign in again instead.
        await ref.read(sessionControllerProvider.notifier).expire();
        return;
      }
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AppAlert(tone: AlertTone.error, title: 'Không thể đổi mật khẩu', message: _error!.userMessage),
            const SizedBox(height: AppSpacing.md),
          ],
          AppTextField(
            label: 'Mật khẩu hiện tại',
            controller: _current,
            obscure: true,
            enabled: !_submitting,
            autofillHints: const [AutofillHints.password],
            validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu hiện tại.' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Mật khẩu mới',
            controller: _new,
            obscure: true,
            enabled: !_submitting,
            autofillHints: const [AutofillHints.newPassword],
            validator: (v) => PasswordPolicy.validateNew(v, current: _current.text),
          ),
          const SizedBox(height: AppSpacing.sm),
          PasswordStrengthMeter(controller: _new),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  PasswordPolicy.byteNote,
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
              ),
              Tooltip(
                message: PasswordPolicy.byteTooltip,
                child: Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Xác nhận mật khẩu mới',
            controller: _confirm,
            obscure: true,
            enabled: !_submitting,
            validator: (v) => PasswordPolicy.validateConfirm(v, _new.text),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Đổi mật khẩu',
            expand: true,
            size: AppButtonSize.mobile,
            loading: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
