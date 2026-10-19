import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/search_field.dart';
import '../../../shared/widgets/staff_table.dart';
import '../../../shared/widgets/status_badge.dart';
import '../application/admin_providers.dart';
import '../data/admin_models.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(accountsQueryProvider);
    final action = ref.watch(adminActionsProvider);
    return PageScaffold(
      title: 'Tài khoản',
      subtitle: 'Quản lý tài khoản sinh viên, thủ thư và quản trị viên',
      actions: [
        AppButton(
            label: 'Tạo tài khoản',
            icon: Icons.add,
            loading: action.isLoading,
            onPressed: () => _create(context, ref))
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 14, runSpacing: 12, children: [
          AppSearchField(
              hint: 'Tìm theo mã, tên hoặc email',
              initialValue: query.q,
              width: 360,
              onChanged: (value) => ref
                  .read(accountsQueryProvider.notifier)
                  .state = query.copyWith(q: value, page: 0)),
          _filter<String>(
              value: query.role,
              hint: 'Vai trò',
              items: const {
                'STUDENT': 'Sinh viên',
                'LIBRARIAN': 'Thủ thư',
                'ADMIN': 'Quản trị viên'
              },
              onChanged: (value) =>
                  ref.read(accountsQueryProvider.notifier).state =
                      query.copyWith(
                          role: value, clearRole: value == null, page: 0)),
          _filter<String>(
              value: query.status,
              hint: 'Trạng thái',
              items: const {'ACTIVE': 'Hoạt động', 'LOCKED': 'Đã khóa'},
              onChanged: (value) =>
                  ref.read(accountsQueryProvider.notifier).state =
                      query.copyWith(
                          status: value, clearStatus: value == null, page: 0)),
        ]),
        const SizedBox(height: 16),
        AsyncValueView(
          value: ref.watch(accountsProvider),
          onRetry: () => ref.invalidate(accountsProvider),
          data: (page) => StaffTable<AdminAccount>(
            columns: [
              StaffColumn(
                  header: 'Mã tài khoản',
                  cell: (item) => Text(item.code,
                      style: const TextStyle(fontWeight: FontWeight.w500))),
              StaffColumn(
                  header: 'Họ và tên',
                  cell: (item) => Text(item.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w500))),
              StaffColumn(
                  header: 'Email',
                  minWidth: 190,
                  cell: (item) => Text(item.email)),
              StaffColumn(
                  header: 'Vai trò',
                  cell: (item) => Text(_roleLabel(item.role))),
              StaffColumn(
                  header: 'Trạng thái',
                  cell: (item) => item.status == 'ACTIVE'
                      ? const StatusBadge.active()
                      : const StatusBadge.locked()),
            ],
            rows: page.items,
            page: page.page,
            size: page.size,
            totalElements: page.totalElements,
            onPageChanged: (value) => ref
                .read(accountsQueryProvider.notifier)
                .state = query.copyWith(page: value),
            empty: const StaffEmpty(
                title: 'Chưa có tài khoản',
                message: 'Hãy tạo tài khoản đầu tiên hoặc thay đổi bộ lọc.'),
          ),
        ),
      ]),
    );
  }

  Widget _filter<T>(
          {required T? value,
          required String hint,
          required Map<T, String> items,
          required ValueChanged<T?> onChanged}) =>
      SizedBox(
        width: 160,
        child: DropdownButtonFormField<T>(
          isExpanded: true,
          initialValue: value,
          hint: Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          items: [
            DropdownMenuItem<T>(
              value: null,
              child: const Text(
                'Tất cả',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ...items.entries.map(
              (entry) => DropdownMenuItem(
                value: entry.key,
                child: Text(
                  entry.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
          ],
          onChanged: onChanged,
        ),
      );

  String _roleLabel(String role) => switch (role) {
        'STUDENT' => 'Sinh viên',
        'LIBRARIAN' => 'Thủ thư',
        'ADMIN' => 'Quản trị viên',
        _ => role
      };

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final key = GlobalKey<FormState>();
    final code = TextEditingController();
    final email = TextEditingController();
    final name = TextEditingController();
    final password = TextEditingController();
    var role = 'STUDENT';
    var mustChangePassword = true;
    var submitting = false;
    Map<String, String> fieldErrors = const {};

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
                title: const Text('Tạo tài khoản'),
                content: SizedBox(
                    width: 620,
                    child: Form(
                        key: key,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                              AppTextField(
                                  label: 'Họ và tên',
                                  controller: name,
                                  hint: 'Nhập họ và tên đầy đủ',
                                  errorText: fieldErrors['fullName'],
                                  validator: _required),
                              const SizedBox(height: 14),
                              AppTextField(
                                  label: 'Mã tài khoản',
                                  controller: code,
                                  hint: 'VD: SV123, LIB004',
                                  errorText: fieldErrors['code'],
                                  validator: _required),
                              const SizedBox(height: 14),
                              AppTextField(
                                  label: 'Email',
                                  controller: email,
                                  hint: 'ten@example.edu.vn',
                                  keyboardType: TextInputType.emailAddress,
                                  errorText: fieldErrors['email'],
                                  validator: (value) => value != null &&
                                          RegExp(r'^[^@]+@[^@]+\.[^@]+$')
                                              .hasMatch(value.trim())
                                      ? null
                                      : 'Email không hợp lệ.'),
                              const SizedBox(height: 14),
                              AppTextField(
                                  label: 'Mật khẩu ban đầu',
                                  controller: password,
                                  hint: 'Từ 12 đến 64 ký tự',
                                  obscure: true,
                                  errorText: fieldErrors['password'],
                                  validator: (value) => value != null &&
                                          value.length >= 12 &&
                                          value.length <= 64
                                      ? null
                                      : 'Mật khẩu phải có từ 12 đến 64 ký tự.'),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                  initialValue: role,
                                  decoration: const InputDecoration(
                                      labelText: 'Vai trò'),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'STUDENT',
                                        child: Text('Sinh viên')),
                                    DropdownMenuItem(
                                        value: 'LIBRARIAN',
                                        child: Text('Thủ thư')),
                                    DropdownMenuItem(
                                        value: 'ADMIN',
                                        child: Text('Quản trị viên'))
                                  ],
                                  onChanged: submitting
                                      ? null
                                      : (value) =>
                                          setState(() => role = value!)),
                              CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  value: mustChangePassword,
                                  onChanged: submitting
                                      ? null
                                      : (value) => setState(() =>
                                          mustChangePassword = value ?? true),
                                  title: const Text(
                                      'Yêu cầu đổi mật khẩu ở lần đăng nhập đầu tiên')),
                            ])))),
                actions: [
                  AppButton(
                      label: 'Hủy',
                      variant: AppButtonVariant.secondary,
                      onPressed: submitting
                          ? null
                          : () => Navigator.pop(dialogContext)),
                  AppButton(
                      label: 'Tạo tài khoản',
                      loading: submitting,
                      onPressed: () async {
                        if (!(key.currentState?.validate() ?? false)) return;
                        setState(() {
                          submitting = true;
                          fieldErrors = const {};
                        });
                        try {
                          await ref
                              .read(adminActionsProvider.notifier)
                              .createAccount({
                            'code': code.text.trim(),
                            'email': email.text.trim(),
                            'fullName': name.text.trim(),
                            'role': role,
                            'password': password.text,
                            'mustChangePassword': mustChangePassword
                          });
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        } on ApiException catch (error) {
                          if (!dialogContext.mounted) return;
                          setState(() {
                            submitting = false;
                            fieldErrors = {
                              for (final item in error.fieldErrors)
                                item.field: item.message
                            };
                          });
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text(error.userMessage)));
                        } catch (_) {
                          if (dialogContext.mounted) {
                            setState(() => submitting = false);
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Không thể tạo tài khoản. Vui lòng thử lại.')));
                          }
                        }
                      }),
                ],
              )),
    );
    code.dispose();
    email.dispose();
    name.dispose();
    password.dispose();
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? 'Thông tin này là bắt buộc.'
      : null;
}
