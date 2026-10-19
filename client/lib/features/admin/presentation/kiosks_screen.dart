import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/search_field.dart';
import '../../../shared/widgets/staff_table.dart';
import '../../../shared/widgets/status_badge.dart';
import '../application/admin_providers.dart';
import '../data/admin_models.dart';

class KiosksScreen extends ConsumerWidget {
  const KiosksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(kiosksQueryProvider);
    final action = ref.watch(adminActionsProvider);
    return PageScaffold(
      title: 'Thiết bị Kiosk',
      subtitle: 'Quản lý thông tin thiết bị và khóa truy cập',
      actions: [
        AppButton(
            label: 'Thêm kiosk',
            icon: Icons.add,
            loading: action.isLoading,
            onPressed: () => _create(context, ref))
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 14, runSpacing: 12, children: [
          AppSearchField(
              hint: 'Tìm theo mã hoặc tên thiết bị',
              initialValue: query.q,
              width: 360,
              onChanged: (value) => ref
                  .read(kiosksQueryProvider.notifier)
                  .state = query.copyWith(q: value, page: 0)),
          _filter<String>(
              value: query.status,
              hint: 'Trạng thái',
              items: const {'ACTIVE': 'Hoạt động', 'REVOKED': 'Đã thu hồi'},
              onChanged: (value) =>
                  ref.read(kiosksQueryProvider.notifier).state = query.copyWith(
                      status: value, clearStatus: value == null, page: 0)),
          _filter<bool>(
              value: query.online,
              hint: 'Kết nối',
              items: const {true: 'Trực tuyến', false: 'Ngoại tuyến'},
              onChanged: (value) =>
                  ref.read(kiosksQueryProvider.notifier).state = query.copyWith(
                      online: value, clearOnline: value == null, page: 0)),
        ]),
        const SizedBox(height: 16),
        AsyncValueView(
          value: ref.watch(kiosksProvider),
          onRetry: () => ref.invalidate(kiosksProvider),
          data: (page) => StaffTable<AdminKiosk>(
            columns: [
              StaffColumn(
                  header: 'Mã thiết bị',
                  cell: (item) => Text(item.code,
                      style: const TextStyle(fontWeight: FontWeight.w500))),
              StaffColumn(header: 'Tên', cell: (item) => Text(item.name)),
              StaffColumn(
                  header: 'Chế độ', cell: (item) => Text(_mode(item.mode))),
              StaffColumn(
                  header: 'Trạng thái',
                  cell: (item) => item.status == 'ACTIVE'
                      ? const StatusBadge.active()
                      : const StatusBadge(
                          label: 'Đã thu hồi',
                          tone: BadgeTone.error,
                          icon: Icons.block)),
              StaffColumn(
                  header: 'Tín hiệu gần nhất',
                  minWidth: 160,
                  cell: (item) => item.isOnline
                      ? const StatusBadge(
                          label: 'Đang trực tuyến',
                          tone: BadgeTone.success,
                          icon: Icons.wifi)
                      : const StatusBadge.disconnected()),
            ],
            rows: page.items,
            page: page.page,
            size: page.size,
            totalElements: page.totalElements,
            onPageChanged: (value) => ref
                .read(kiosksQueryProvider.notifier)
                .state = query.copyWith(page: value),
            onRowTap: (item) => _edit(context, ref, item.id),
            empty: const StaffEmpty(
                title: 'Chưa có kiosk',
                message: 'Hãy thêm kiosk đầu tiên hoặc thay đổi bộ lọc.',
                icon: Icons.devices_other_outlined),
          ),
        ),
      ]),
    );
  }

  String _mode(String value) => switch (value) {
        'ENTRY' => 'Chỉ vào',
        'EXIT' => 'Chỉ ra',
        'AUTO' => 'Tự động',
        _ => value
      };
  Widget _filter<T>(
          {required T? value,
          required String hint,
          required Map<T, String> items,
          required ValueChanged<T?> onChanged}) =>
      SizedBox(
          width: 160,
          child: DropdownButtonFormField<T>(
              initialValue: value,
              hint: Text(hint),
              items: [
                DropdownMenuItem<T>(value: null, child: const Text('Tất cả')),
                ...items.entries.map((entry) => DropdownMenuItem(
                    value: entry.key, child: Text(entry.value)))
              ],
              onChanged: onChanged));

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final key = GlobalKey<FormState>();
    final code = TextEditingController();
    final name = TextEditingController();
    var mode = 'AUTO';
    var loading = false;
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
            builder: (_, setState) => AlertDialog(
                  title: const Text('Thêm kiosk'),
                  content: SizedBox(
                      width: 460,
                      child: Form(
                          key: key,
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            AppTextField(
                                label: 'Mã kiosk',
                                controller: code,
                                hint: 'VD: KIOSK-05',
                                validator: _required),
                            const SizedBox(height: 16),
                            AppTextField(
                                label: 'Tên thiết bị',
                                controller: name,
                                hint: 'Nhập tên thiết bị',
                                validator: _required),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                                initialValue: mode,
                                decoration:
                                    const InputDecoration(labelText: 'Chế độ'),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'ENTRY', child: Text('Chỉ vào')),
                                  DropdownMenuItem(
                                      value: 'EXIT', child: Text('Chỉ ra')),
                                  DropdownMenuItem(
                                      value: 'AUTO', child: Text('Tự động'))
                                ],
                                onChanged: loading
                                    ? null
                                    : (value) => setState(() => mode = value!)),
                          ]))),
                  actions: [
                    AppButton(
                        label: 'Hủy',
                        variant: AppButtonVariant.secondary,
                        onPressed: loading ? null : () => Navigator.pop(ctx)),
                    AppButton(
                        label: 'Thêm kiosk',
                        loading: loading,
                        onPressed: () async {
                          if (!(key.currentState?.validate() ?? false)) return;
                          setState(() => loading = true);
                          try {
                            final result = await ref
                                .read(adminActionsProvider.notifier)
                                .createKiosk({
                              'code': code.text.trim(),
                              'name': name.text.trim(),
                              'mode': mode
                            });
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            await _showCredential(context, result.credential);
                          } on ApiException catch (error) {
                            if (ctx.mounted) {
                              setState(() => loading = false);
                              _showError(ctx, error);
                            }
                          }
                        }),
                  ],
                )));
    code.dispose();
    name.dispose();
  }

  Future<void> _showCredential(BuildContext context, String credential) =>
      showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
                title: const Text('Lưu khóa truy cập ngay'),
                content: SizedBox(
                    width: 520,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                              'Khóa này chỉ hiển thị một lần. Hãy sao chép và lưu tại nơi an toàn.'),
                          const SizedBox(height: 16),
                          SelectableText(credential,
                              style: const TextStyle(fontFamily: 'monospace')),
                        ])),
                actions: [
                  AppButton(
                      label: 'Sao chép',
                      variant: AppButtonVariant.secondary,
                      icon: Icons.copy_outlined,
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: credential));
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content: Text('Đã sao chép khóa.')));
                        }
                      }),
                  AppButton(
                      label: 'Đã lưu', onPressed: () => Navigator.pop(ctx))
                ],
              ));

  Future<void> _edit(BuildContext context, WidgetRef ref, String id) async {
    AdminKiosk item;
    try {
      item = await ref.read(kioskDetailProvider(id).future);
    } on ApiException catch (error) {
      if (context.mounted) _showError(context, error);
      return;
    }
    if (!context.mounted) return;
    final name = TextEditingController(text: item.name);
    var mode = item.mode;
    var loading = false;
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
            builder: (_, setState) => AlertDialog(
                  title: Text('Chi tiết kiosk · ${item.code}'),
                  content: SizedBox(
                      width: 680,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppTextField(
                                label: 'Tên thiết bị',
                                controller: name,
                                enabled: !loading),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                                initialValue: mode,
                                decoration:
                                    const InputDecoration(labelText: 'Chế độ'),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'ENTRY', child: Text('Chỉ vào')),
                                  DropdownMenuItem(
                                      value: 'EXIT', child: Text('Chỉ ra')),
                                  DropdownMenuItem(
                                      value: 'AUTO', child: Text('Tự động'))
                                ],
                                onChanged: loading
                                    ? null
                                    : (value) => setState(() => mode = value!)),
                            const SizedBox(height: 20),
                            const Divider(),
                            Wrap(spacing: 12, runSpacing: 8, children: [
                              AppButton(
                                  label: 'Cấp lại khóa',
                                  variant: AppButtonVariant.secondary,
                                  onPressed: loading
                                      ? null
                                      : () async {
                                          if (!await showConfirmDialog(ctx,
                                              title: 'Cấp lại khóa?',
                                              message:
                                                  'Khóa hiện tại sẽ hết hiệu lực ngay lập tức.',
                                              confirmLabel: 'Cấp lại khóa',
                                              destructive: true)) {
                                            return;
                                          }
                                          setState(() => loading = true);
                                          try {
                                            final result = await ref
                                                .read(adminActionsProvider
                                                    .notifier)
                                                .rotateKioskCredential(
                                                    item.id, item.version);
                                            if (ctx.mounted) {
                                              Navigator.pop(ctx);
                                            }
                                            if (context.mounted) {
                                              await _showCredential(
                                                  context, result.credential);
                                            }
                                          } on ApiException catch (error) {
                                            if (ctx.mounted) {
                                              setState(() => loading = false);
                                              _showError(ctx, error);
                                            }
                                          }
                                        }),
                              AppButton(
                                  label: 'Thu hồi thiết bị',
                                  variant: AppButtonVariant.destructive,
                                  onPressed: loading || item.status == 'REVOKED'
                                      ? null
                                      : () async {
                                          if (!await showConfirmDialog(ctx,
                                              title: 'Thu hồi thiết bị?',
                                              message:
                                                  'Kiosk sẽ không thể tiếp tục truy cập hệ thống.',
                                              confirmLabel: 'Thu hồi',
                                              destructive: true)) {
                                            return;
                                          }
                                          setState(() => loading = true);
                                          try {
                                            await ref
                                                .read(adminActionsProvider
                                                    .notifier)
                                                .updateKiosk(item.id, {
                                              'version': item.version,
                                              'status': 'REVOKED'
                                            });
                                            if (ctx.mounted) {
                                              Navigator.pop(ctx);
                                            }
                                          } on ApiException catch (error) {
                                            if (ctx.mounted) {
                                              setState(() => loading = false);
                                              _showError(ctx, error);
                                            }
                                          }
                                        }),
                            ]),
                          ])),
                  actions: [
                    AppButton(
                        label: 'Đóng',
                        variant: AppButtonVariant.secondary,
                        onPressed: loading ? null : () => Navigator.pop(ctx)),
                    AppButton(
                        label: 'Lưu thay đổi',
                        loading: loading,
                        onPressed: () async {
                          final changes = <String, dynamic>{
                            'version': item.version
                          };
                          if (name.text.trim() != item.name) {
                            changes['name'] = name.text.trim();
                          }
                          if (mode != item.mode) changes['mode'] = mode;
                          if (changes.length == 1) {
                            Navigator.pop(ctx);
                            return;
                          }
                          setState(() => loading = true);
                          try {
                            await ref
                                .read(adminActionsProvider.notifier)
                                .updateKiosk(item.id, changes);
                            if (ctx.mounted) Navigator.pop(ctx);
                          } on ApiException catch (error) {
                            if (ctx.mounted) {
                              setState(() => loading = false);
                              _showError(ctx, error);
                            }
                          }
                        }),
                  ],
                )));
    name.dispose();
  }

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty
          ? 'Thông tin này là bắt buộc.'
          : null;
  static void _showError(BuildContext context, ApiException error) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.userMessage), backgroundColor: AppColors.error));
}
