import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../application/session_controller.dart';
import 'widgets/auth_card.dart';

/// AUTH-01 — Login. Router redirects to the role home on success.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  ApiException? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(sessionControllerProvider.notifier).login(
            identifier: _identifier.text,
            password: _password.text,
          );
      TextInput.finishAutofillContext();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthCard(
      title: 'Đăng nhập',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                AppAlert(
                  tone: AlertTone.error,
                  title: 'Không thể đăng nhập',
                  message: _error!.userMessage,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AppTextField(
                label: 'Mã tài khoản hoặc email',
                hint: 'VD: SV001 hoặc ten@example.edu.vn',
                controller: _identifier,
                enabled: !_submitting,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Vui lòng nhập mã tài khoản hoặc email.' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Mật khẩu',
                controller: _password,
                obscure: true,
                enabled: !_submitting,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu.' : null,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Đăng nhập',
                size: AppButtonSize.mobile,
                expand: true,
                loading: _submitting,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Chưa có tài khoản hoặc quên mật khẩu? Vui lòng liên hệ quản trị viên.',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
