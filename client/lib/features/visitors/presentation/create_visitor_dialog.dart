import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../application/visitors_providers.dart';
import '../data/models/visitor.dart';
import '../data/visitors_repository.dart';

Future<Visitor?> showCreateVisitorDialog(BuildContext context) {
  return showDialog<Visitor>(
    context: context,
    builder: (_) => const _CreateVisitorDialog(),
  );
}

class _CreateVisitorDialog extends ConsumerStatefulWidget {
  const _CreateVisitorDialog();

  @override
  ConsumerState<_CreateVisitorDialog> createState() => _CreateVisitorDialogState();
}

class _CreateVisitorDialogState extends ConsumerState<_CreateVisitorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _submitting = false;
  ApiException? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created = await ref.read(visitorsRepositoryProvider).create(fullName: _name.text.trim());
      ref.invalidate(visitorsListProvider);
      if (mounted) Navigator.of(context).pop(created);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Thêm khách ngoài', style: AppTypography.h3),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                AppAlert(tone: AlertTone.error, title: 'Không thể thêm khách', message: _error!.userMessage),
                const SizedBox(height: AppSpacing.md),
              ],
              AppTextField(
                label: 'Họ và tên',
                controller: _name,
                hint: 'VD: Ngô Thanh Hà',
                helper: 'Mã khách sẽ được hệ thống tự tạo. Thêm khách không tự động ghi nhận vào thư viện.',
                enabled: !_submitting,
                validator: (v) {
                  final name = v?.trim() ?? '';
                  if (name.isEmpty) return 'Vui lòng nhập họ và tên.';
                  if (name.length > 150) return 'Họ và tên tối đa 150 ký tự.';
                  return null;
                },
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      actions: [
        AppButton(
          label: 'Hủy',
          variant: AppButtonVariant.secondary,
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: 'Thêm khách',
          loading: _submitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}
