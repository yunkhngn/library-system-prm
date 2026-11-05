import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/labeled_value.dart';
import '../../../../shared/widgets/side_sheet.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../application/admin_providers.dart';
import '../../data/admin_models.dart';

Future<void> showAdminShiftDetail(
  BuildContext context,
  AdminShift shift, {
  required ValueChanged<AdminShift> onCancelShift,
}) =>
    showSideSheet(
      context,
      title: 'Chi tiết ca trực',
      builder: (_) =>
          AdminShiftDetail(shift: shift, onCancelShift: onCancelShift),
    );

class AdminShiftDetail extends ConsumerStatefulWidget {
  const AdminShiftDetail(
      {super.key, required this.shift, required this.onCancelShift});

  /// Snapshot from the week view, shown until the fresh copy arrives.
  final AdminShift shift;
  final ValueChanged<AdminShift> onCancelShift;

  @override
  ConsumerState<AdminShiftDetail> createState() => _AdminShiftDetailState();
}

class _AdminShiftDetailState extends ConsumerState<AdminShiftDetail> {
  bool _busy = false;

  String get _id => widget.shift.id;

  @override
  Widget build(BuildContext context) {
    ref.watch(adminActionsProvider);
    final shiftValue = ref.watch(adminShiftProvider(_id));
    final assignments = ref.watch(shiftAssignmentsProvider(_id));
    final shift = shiftValue.valueOrNull ?? widget.shift;
    // Mutations need the latest shift/assignment versions, so wait for reloads.
    final locked = _busy ||
        !shiftValue.hasValue ||
        shiftValue.isLoading ||
        !assignments.hasValue ||
        assignments.isLoading;
    final muted = AppTypography.bodyM.copyWith(color: AppColors.textSecondary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(shift.name, style: AppTypography.h2),
        const SizedBox(height: AppSpacing.lg),
        LabeledValue(
          label: 'Trạng thái',
          child: Align(
            alignment: Alignment.centerLeft,
            child: shift.isActive
                ? const StatusBadge(
                    label: 'Đang hoạt động',
                    tone: BadgeTone.success,
                    icon: Icons.event_available_outlined)
                : const StatusBadge.cancelled(),
          ),
        ),
        LabeledValue(
            label: 'Bắt đầu',
            value:
                '${Fmt.time(shift.startsAt)}, ${Fmt.longDate(shift.startsAt)}'),
        LabeledValue(
            label: 'Kết thúc',
            value: '${Fmt.time(shift.endsAt)}, ${Fmt.longDate(shift.endsAt)}'),
        LabeledValue(
            label: 'Thời lượng',
            value: Fmt.duration(shift.endsAt.difference(shift.startsAt))),
        if (!shift.isActive && (shift.cancellationReason?.isNotEmpty ?? false))
          LabeledValue(label: 'Lý do hủy', value: shift.cancellationReason),
        const Divider(height: AppSpacing.xl),
        Text('Thủ thư được phân công', style: AppTypography.h3),
        const SizedBox(height: AppSpacing.sm),
        assignments.when(
          skipLoadingOnRefresh: true,
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Row(children: [
            Expanded(
                child: Text(
                    error is ApiException
                        ? error.userMessage
                        : 'Không tải được danh sách phân công.',
                    style: muted)),
            TextButton(
                onPressed: () => ref.invalidate(shiftAssignmentsProvider(_id)),
                child: const Text('Thử lại')),
          ]),
          data: (list) => list.isEmpty
              ? Text('Chưa có thủ thư nào được phân vào ca này.', style: muted)
              : Column(children: [
                  for (final a in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.navy,
                        child: Text(a.staff.initials,
                            style: AppTypography.caption
                                .copyWith(color: Colors.white)),
                      ),
                      title: Text(a.staff.fullName, style: AppTypography.label),
                      subtitle:
                          Text(a.staff.code, style: AppTypography.caption),
                      trailing: shift.isActive
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                tooltip: 'Đổi người',
                                icon: const Icon(Icons.swap_horiz),
                                onPressed:
                                    locked ? null : () => _replace(a, list),
                              ),
                              IconButton(
                                tooltip: 'Gỡ khỏi ca',
                                icon: Icon(Icons.person_remove_outlined,
                                    color: AppColors.error),
                                onPressed: locked ? null : () => _remove(a),
                              ),
                            ])
                          : null,
                    ),
                ]),
        ),
        if (shift.isActive) ...[
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Phân công thủ thư',
            icon: Icons.person_add_alt_1_outlined,
            expand: true,
            loading: _busy,
            onPressed: locked
                ? null
                : () => _assign(shift, assignments.valueOrNull ?? const []),
          ),
          const Divider(height: AppSpacing.xl),
          AppButton(
            label: 'Hủy ca trực',
            variant: AppButtonVariant.destructive,
            expand: true,
            onPressed: locked
                ? null
                : () {
                    Navigator.of(context).pop();
                    widget.onCancelShift(shift);
                  },
          ),
        ],
      ],
    );
  }

  Future<void> _assign(AdminShift shift, List<AdminAssignment> current) async {
    final ids = await showDialog<List<String>>(
      context: context,
      builder: (_) => _LibrarianPicker(
        title: 'Phân công thủ thư',
        confirmLabel: 'Phân công',
        multiple: true,
        excluded: {for (final a in current) a.staff.id},
      ),
    );
    if (ids == null || ids.isEmpty) return;
    await _mutate(
      () => ref
          .read(adminActionsProvider.notifier)
          .assignStaff(_id, shift.version, ids),
      'Đã phân công ${ids.length} thủ thư vào ca.',
    );
  }

  Future<void> _replace(
      AdminAssignment assignment, List<AdminAssignment> current) async {
    final ids = await showDialog<List<String>>(
      context: context,
      builder: (_) => _LibrarianPicker(
        title: 'Đổi ${assignment.staff.fullName} bằng',
        confirmLabel: 'Đổi người',
        multiple: false,
        excluded: {for (final a in current) a.staff.id},
      ),
    );
    if (ids == null || ids.isEmpty) return;
    await _mutate(
      () => ref
          .read(adminActionsProvider.notifier)
          .replaceAssignedStaff(_id, assignment, ids.single),
      'Đã đổi thủ thư trong ca.',
    );
  }

  Future<void> _remove(AdminAssignment assignment) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Gỡ ${assignment.staff.fullName} khỏi ca?',
      message: 'Thủ thư này sẽ không còn thấy ca trong lịch trực của mình.',
      confirmLabel: 'Gỡ khỏi ca',
      destructive: true,
    );
    if (!confirmed) return;
    await _mutate(
      () => ref
          .read(adminActionsProvider.notifier)
          .cancelAssignment(_id, assignment),
      'Đã gỡ ${assignment.staff.fullName} khỏi ca.',
    );
  }

  Future<void> _mutate(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } catch (error) {
      ref.read(adminActionsProvider.notifier).refreshShift(_id);
      messenger.showSnackBar(SnackBar(
          content: Text(error is ApiException
              ? error.userMessage
              : 'Không thể cập nhật phân công. Vui lòng thử lại.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Returns the chosen staff ids; [multiple] = false allows exactly one.
class _LibrarianPicker extends ConsumerStatefulWidget {
  const _LibrarianPicker({
    required this.title,
    required this.confirmLabel,
    required this.multiple,
    required this.excluded,
  });

  final String title, confirmLabel;
  final bool multiple;
  final Set<String> excluded;

  @override
  ConsumerState<_LibrarianPicker> createState() => _LibrarianPickerState();
}

class _LibrarianPickerState extends ConsumerState<_LibrarianPicker> {
  final _selected = <String>{};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final librarians = ref.watch(assignableLibrariansProvider);
    final muted = AppTypography.bodyM.copyWith(color: AppColors.textSecondary);
    return AlertDialog(
      title: Text(widget.title, style: AppTypography.h3),
      content: SizedBox(
        width: 440,
        height: 420,
        child: Column(children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Tìm theo tên hoặc mã thủ thư',
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
            ),
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: librarians.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                      error is ApiException
                          ? error.userMessage
                          : 'Không tải được danh sách thủ thư.',
                      style: muted,
                      textAlign: TextAlign.center),
                  TextButton(
                      onPressed: () =>
                          ref.invalidate(assignableLibrariansProvider),
                      child: const Text('Thử lại')),
                ]),
              ),
              data: (items) {
                final candidates = items
                    .where((u) => !widget.excluded.contains(u.id))
                    .where((u) =>
                        _query.isEmpty ||
                        u.fullName.toLowerCase().contains(_query) ||
                        u.code.toLowerCase().contains(_query))
                    .toList();
                if (candidates.isEmpty) {
                  return Center(
                      child: Text(
                          _query.isEmpty
                              ? 'Không còn thủ thư đang hoạt động nào để phân công.'
                              : 'Không tìm thấy thủ thư phù hợp.',
                          style: muted,
                          textAlign: TextAlign.center));
                }
                return ListView(children: [
                  for (final u in candidates)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _selected.contains(u.id),
                      title: Text(u.fullName, style: AppTypography.label),
                      subtitle: Text(u.code, style: AppTypography.caption),
                      onChanged: (checked) => setState(() {
                        if (!widget.multiple) _selected.clear();
                        if (checked ?? false) {
                          _selected.add(u.id);
                        } else {
                          _selected.remove(u.id);
                        }
                      }),
                    ),
                ]);
              },
            ),
          ),
        ]),
      ),
      actions: [
        AppButton(
          label: 'Hủy',
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: widget.multiple && _selected.isNotEmpty
              ? '${widget.confirmLabel} (${_selected.length})'
              : widget.confirmLabel,
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selected.toList()),
        ),
      ],
    );
  }
}
