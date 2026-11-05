import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../application/admin_providers.dart';
import '../data/admin_models.dart';
import 'widgets/shift_detail_sheet.dart';

class ShiftsScreen extends ConsumerStatefulWidget {
  const ShiftsScreen({super.key});

  @override
  ConsumerState<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends ConsumerState<ShiftsScreen> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = _startOfWeek(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    // Keep mutation state alive while a create/cancel request is in flight.
    // Reading only the notifier in a dialog lets this auto-dispose provider
    // disappear before it can invalidate the shifts list after the response.
    ref.watch(adminActionsProvider);
    final end = _weekStart.add(const Duration(days: 6));
    return PageScaffold(
      title: 'Phân ca nhân viên',
      subtitle: 'Tuần ${Fmt.dayMonth(_weekStart)} – ${Fmt.date(end)}',
      actions: [
        AppButton(
            label: 'Tạo ca trực',
            icon: Icons.add,
            onPressed: () => _create(context))
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          OutlinedButton(
              onPressed: () =>
                  _setWeek(_weekStart.subtract(const Duration(days: 7))),
              child: const Text('‹')),
          const SizedBox(width: 8),
          OutlinedButton(
              onPressed: () => _setWeek(DateTime.now()
                  .subtract(Duration(days: DateTime.now().weekday - 1))),
              child: const Text('Hôm nay')),
          const SizedBox(width: 8),
          OutlinedButton(
              onPressed: () =>
                  _setWeek(_weekStart.add(const Duration(days: 7))),
              child: const Text('›')),
        ]),
        const SizedBox(height: 20),
        AsyncValueView(
          value: ref.watch(shiftsProvider),
          onRetry: () => ref.invalidate(shiftsProvider),
          data: (page) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var day = 0; day < 7; day++) ...[
                _DayColumn(
                  date: _weekStart.add(Duration(days: day)),
                  shifts: page.items.where((shift) {
                    final start = Fmt.toVietnam(shift.startsAt);
                    final date = _weekStart.add(Duration(days: day));
                    return start.year == date.year &&
                        start.month == date.month &&
                        start.day == date.day;
                  }).toList(),
                  onOpen: (shift) => showAdminShiftDetail(context, shift,
                      onCancelShift: (latest) => _cancel(
                          context, latest.id, latest.version, latest.name)),
                ),
                if (day < 6) const SizedBox(width: 10),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  void _setWeek(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);
    setState(() => _weekStart = normalized);
    ref.read(shiftRangeProvider.notifier).state = normalized;
  }

  DateTime _startOfWeek(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  Future<void> _create(BuildContext context) async {
    final name = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          var date = _weekStart;
          var startsAt = const TimeOfDay(hour: 7, minute: 30);
          var endsAt = const TimeOfDay(hour: 12, minute: 0);
          var saving = false;
          var submitted = false;
          String? validationMessage;
          return StatefulBuilder(
            builder: (ctx, setDialogState) => AlertDialog(
              title: const Text('Tạo ca trực'),
              content: SizedBox(
                  width: 480,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                            label: 'Tên ca',
                            controller: name,
                            errorText: validationMessage,
                            hint: 'Ví dụ: Ca sáng'),
                        const SizedBox(height: 16),
                        Text('Ngày trực', style: AppTypography.label),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(Fmt.date(date)),
                          onPressed: saving
                              ? null
                              : () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: date,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null && ctx.mounted) {
                                    setDialogState(() => date = picked);
                                  }
                                },
                        ),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                            child: _timePickerButton(
                              context: ctx,
                              label: 'Bắt đầu',
                              value: startsAt,
                              enabled: !saving,
                              onSelected: (value) =>
                                  setDialogState(() => startsAt = value),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _timePickerButton(
                              context: ctx,
                              label: 'Kết thúc',
                              value: endsAt,
                              enabled: !saving,
                              onSelected: (value) =>
                                  setDialogState(() => endsAt = value),
                            ),
                          ),
                        ]),
                      ])),
              actions: [
                AppButton(
                    label: 'Hủy',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.pop(ctx)),
                AppButton(
                    label: 'Tạo ca trực',
                    loading: saving,
                    onPressed: () async {
                      if (name.text.trim().isEmpty) {
                        setDialogState(() =>
                            validationMessage = 'Vui lòng nhập tên ca trực.');
                        return;
                      }
                      final start = DateTime(date.year, date.month, date.day,
                          startsAt.hour, startsAt.minute);
                      final end = DateTime(date.year, date.month, date.day,
                          endsAt.hour, endsAt.minute);
                      if (!end.isAfter(start)) {
                        setDialogState(() => validationMessage =
                            'Giờ kết thúc phải sau giờ bắt đầu.');
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await ref
                            .read(adminActionsProvider.notifier)
                            .createShift({
                          'name': name.text.trim(),
                          'startsAt': start.toUtc().toIso8601String(),
                          'endsAt': end.toUtc().toIso8601String(),
                        });
                        if (ctx.mounted) {
                          submitted = true;
                          Navigator.pop(ctx);
                        }
                      } catch (error) {
                        if (ctx.mounted) {
                          final message = error is ApiException
                              ? error.userMessage
                              : 'Không thể tạo ca trực. Vui lòng thử lại.';
                          ScaffoldMessenger.of(ctx)
                              .showSnackBar(SnackBar(content: Text(message)));
                        }
                      } finally {
                        if (!submitted && ctx.mounted) {
                          setDialogState(() => saving = false);
                        }
                      }
                    }),
              ],
            ),
          );
        },
      );
    } finally {
      name.dispose();
    }
  }

  Widget _timePickerButton({
    required BuildContext context,
    required String label,
    required TimeOfDay value,
    required bool enabled,
    required ValueChanged<TimeOfDay> onSelected,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label, style: AppTypography.label),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          icon: const Icon(Icons.schedule_outlined),
          label: Text(value.format(context)),
          onPressed: !enabled
              ? null
              : () async {
                  final picked = await showTimePicker(
                      context: context, initialTime: value);
                  if (picked != null) onSelected(picked);
                },
        ),
      ]);

  Future<void> _cancel(
      BuildContext context, String id, int version, String name) async {
    final reason = TextEditingController();
    var saving = false;
    String? validationMessage;
    try {
      await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => StatefulBuilder(
              builder: (ctx, setDialogState) => AlertDialog(
                    contentPadding: const EdgeInsets.fromLTRB(30, 28, 30, 10),
                    content: SizedBox(
                        width: 520,
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(children: [
                                CircleAvatar(
                                    backgroundColor: AppColors.errorSurface,
                                    child: Text('!',
                                        style: TextStyle(
                                            color: AppColors.error,
                                            fontWeight: FontWeight.w700))),
                                const SizedBox(width: 16),
                                Expanded(
                                    child: Text('Hủy ca $name?',
                                        style: AppTypography.h3
                                            .copyWith(fontSize: 20))),
                              ]),
                              const SizedBox(height: 26),
                              Text(
                                  'Tất cả phân công trong ca sẽ bị hủy theo. Ca đã hủy chỉ có thể xem, không thể mở lại.',
                                  style: AppTypography.bodyM.copyWith(
                                      color: AppColors.textSecondary)),
                              const SizedBox(height: 28),
                              AppTextField(
                                  label: 'Lý do hủy ca trực (bắt buộc)',
                                  controller: reason,
                                  enabled: !saving,
                                  errorText: validationMessage,
                                  maxLines: 4,
                                  hint: 'Nhập lý do hủy để lưu vào lịch sử…'),
                            ])),
                    actions: [
                      AppButton(
                          label: 'Giữ ca trực',
                          variant: AppButtonVariant.secondary,
                          onPressed: saving ? null : () => Navigator.pop(ctx)),
                      AppButton(
                        label: 'Hủy ca trực',
                        variant: AppButtonVariant.destructive,
                        loading: saving,
                        onPressed: () async {
                          if (reason.text.trim().isEmpty) {
                            setDialogState(() => validationMessage =
                                'Vui lòng nhập lý do hủy ca trực.');
                            return;
                          }
                          setDialogState(() {
                            saving = true;
                            validationMessage = null;
                          });
                          try {
                            await ref
                                .read(adminActionsProvider.notifier)
                                .cancelShift(id, {
                              'version': version,
                              'reason': reason.text.trim()
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                          } on ApiException catch (error) {
                            if (ctx.mounted) {
                              setDialogState(() => saving = false);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(error.userMessage)));
                            }
                          } catch (_) {
                            if (ctx.mounted) {
                              setDialogState(() => saving = false);
                              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                                  content: Text(
                                      'Không thể hủy ca trực. Vui lòng thử lại.')));
                            }
                          }
                        },
                      ),
                    ],
                  )));
    } finally {
      reason.dispose();
    }
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn(
      {required this.date, required this.shifts, required this.onOpen});
  final DateTime date;
  final List<AdminShift> shifts;
  final ValueChanged<AdminShift> onOpen;

  @override
  Widget build(BuildContext context) {
    const names = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật'
    ];
    return Container(
      width: 148,
      height: 500,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${names[date.weekday - 1]} ${Fmt.dayMonth(date)}',
            style: AppTypography.caption.copyWith(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 38),
        for (final shift in shifts)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => onOpen(shift),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                        left: BorderSide(color: _accent(shift), width: 5))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shift.name,
                          style: AppTypography.caption.copyWith(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(_time(shift),
                          style: AppTypography.caption.copyWith(
                              fontSize: 10, color: AppColors.textPrimary)),
                      Text(_staffing(shift),
                          style: AppTypography.caption.copyWith(
                              fontSize: 10,
                              color: _accent(shift),
                              fontWeight: FontWeight.w600)),
                    ]),
              ),
            ),
          ),
      ]),
    );
  }

  String _time(AdminShift shift) {
    return '${Fmt.time(shift.startsAt)}–${Fmt.time(shift.endsAt)}';
  }

  String _staffing(AdminShift shift) {
    if (!shift.isActive) return 'Đã hủy';
    if (shift.assignmentCount == 0) return 'Chưa phân công';
    return '${shift.assignmentCount} thủ thư';
  }

  Color _accent(AdminShift shift) {
    if (!shift.isActive) return AppColors.textSecondary;
    if (shift.assignmentCount == 0) return AppColors.warning;
    return AppColors.navy;
  }
}
