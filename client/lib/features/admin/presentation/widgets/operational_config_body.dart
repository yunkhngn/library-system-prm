import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../system_config/data/models/system_config.dart';
import 'admin_ui.dart';

class OperationalConfigBody extends StatelessWidget {
  const OperationalConfigBody({
    super.key,
    required this.config,
    required this.hours,
    required this.capacity,
    required this.ratio,
    required this.cooldown,
    required this.onChanged,
    required this.onHoursChanged,
  });
  final SystemConfig config;
  final List<OpeningSlot> hours;
  final TextEditingController capacity, ratio, cooldown;
  final VoidCallback onChanged;
  final ValueChanged<List<OpeningSlot>> onHoursChanged;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final left =
            wide ? (constraints.maxWidth - 20) * .64 : constraints.maxWidth;
        final right =
            wide ? constraints.maxWidth - left - 20 : constraints.maxWidth;
        final week = Fmt.startOfVietnamWeek(DateTime.now());
        Widget card(double width, double height, List<Widget> children) =>
            SizedBox(
                width: width,
                child: AdminCard(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: height),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: children)),
                ));
        return Wrap(spacing: 20, runSpacing: 20, children: [
          card(left, 218, [
            const AdminSectionTitle('Giờ mở cửa'),
            const SizedBox(height: 4),
            Text('Thời gian cho phép ghi nhận vào',
                style: AppTypography.caption),
            const SizedBox(height: 14),
            for (var day = 1; day <= 7; day++)
              _openingRow(context, day, week.add(Duration(days: day - 1))),
          ]),
          card(right, 218, [
            const AdminSectionTitle('Sức chứa'),
            const SizedBox(height: 18),
            const AdminFieldLabel('Sức chứa tối đa'),
            _numberField('capacity', capacity, 'người', 1, 100000,
                integer: true),
            const SizedBox(height: 18),
            const AdminFieldLabel('Ngưỡng cảnh báo gần đầy'),
            _numberField('ratio', ratio, '%', 10, 100),
          ]),
          card(left, 130, [
            const AdminSectionTitle('Lượt ra vào'),
            const SizedBox(height: 20),
            Wrap(spacing: 16, runSpacing: 8, children: [
              Text('Thời gian lưu lại tối đa',
                  style: AppTypography.bodyM),
              Text(
                  config.maxSessionDurationMinutes == null
                      ? 'Không giới hạn'
                      : '${config.maxSessionDurationMinutes} phút',
                  style: AppTypography.bodyM
                      .copyWith(color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: Text('Khoảng cách giữa hai lần quét',
                      style: AppTypography.bodyM)),
              const SizedBox(width: 12),
              SizedBox(
                  width: 140,
                  child: _numberField('cooldown', cooldown, 'giây', 1, 60,
                      integer: true)),
            ]),
          ]),
          card(right, 130, [
            const AdminSectionTitle('Múi giờ'),
            const SizedBox(height: 24),
            Text('${config.timezone} (GMT+7)',
                style: AppTypography.bodyM
                    .copyWith(color: AppColors.textSecondary)),
          ]),
        ]);
      });

  Widget _numberField(String key, TextEditingController controller,
          String suffix, num min, num max,
          {bool integer = false}) =>
      TextFormField(
        key: ValueKey(key),
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: !integer),
        onChanged: (_) => onChanged(),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
            suffixText: suffix,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
        validator: (value) {
          final text = (value ?? '').trim().replaceAll(',', '.');
          final number = integer ? int.tryParse(text) : double.tryParse(text);
          if (number == null ||
              !number.isFinite ||
              number < min ||
              number > max) {
            return 'Nhập ${integer ? 'số nguyên ' : ''}từ $min đến $max';
          }
          return null;
        },
      );

  Widget _openingRow(BuildContext context, int day, DateTime date) {
    final matches = hours.where((slot) => slot.dayOfWeek == day);
    final slot = matches.isEmpty ? null : matches.first;
    return InkWell(
      key: ValueKey('opening-day-$day'),
      onTap: () => _editHours(context, day, slot),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(
                child: Text(Fmt.weekdayDayMonth(date),
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textPrimary))),
            Expanded(
                child: Text(
                    slot == null
                        ? 'Đóng cửa'
                        : '${slot.opensAt} – ${slot.closesAt}',
                    style: AppTypography.caption)),
          ])),
    );
  }

  Future<void> _editHours(
      BuildContext context, int day, OpeningSlot? slot) async {
    final result = await showDialog<List<OpeningSlot>>(
        context: context,
        builder: (_) => _OpeningHoursDialog(day: day, slot: slot));
    if (result == null) return;
    onHoursChanged([
      ...hours.where((item) => item.dayOfWeek != day),
      ...result,
    ]..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek)));
  }
}

class _OpeningHoursDialog extends StatefulWidget {
  const _OpeningHoursDialog({required this.day, this.slot});
  final int day;
  final OpeningSlot? slot;
  @override
  State<_OpeningHoursDialog> createState() => _OpeningHoursDialogState();
}

class _OpeningHoursDialogState extends State<_OpeningHoursDialog> {
  final _form = GlobalKey<FormState>();
  late final _open =
      TextEditingController(text: widget.slot?.opensAt ?? '08:00');
  late final _close =
      TextEditingController(text: widget.slot?.closesAt ?? '22:00');
  late bool _closed = widget.slot == null;
  @override
  void dispose() {
    _open.dispose();
    _close.dispose();
    super.dispose();
  }

  String? _validate(String? value) =>
      RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value ?? '')
          ? null
          : 'Nhập giờ theo dạng HH:mm';

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Giờ mở cửa · ${Fmt.weekdayName(widget.day)}'),
        content: SizedBox(
            width: 360,
            child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Đóng cửa'),
                        value: _closed,
                        onChanged: (value) => setState(() => _closed = value)),
                    if (!_closed) ...[
                      TextFormField(
                          controller: _open,
                          decoration:
                              const InputDecoration(labelText: 'Giờ mở cửa'),
                          validator: _validate),
                      const SizedBox(height: 16),
                      TextFormField(
                          controller: _close,
                          decoration:
                              const InputDecoration(labelText: 'Giờ đóng cửa'),
                          validator: (value) =>
                              _validate(value) ??
                              (value == _open.text
                                  ? 'Giờ đóng cửa phải khác giờ mở cửa'
                                  : null)),
                      const SizedBox(height: 12),
                      Text(
                          'Nếu giờ đóng cửa sớm hơn giờ mở cửa, ca kéo dài qua đêm.',
                          style: AppTypography.caption),
                    ],
                  ],
                ))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () {
                if (!_closed && !_form.currentState!.validate()) return;
                Navigator.pop(context, <OpeningSlot>[
                  if (!_closed)
                    OpeningSlot(
                        dayOfWeek: widget.day,
                        opensAt: _open.text,
                        closesAt: _close.text),
                ]);
              },
              child: const Text('Áp dụng')),
        ],
      );
}
