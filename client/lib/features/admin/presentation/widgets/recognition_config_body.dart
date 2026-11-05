import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../system_config/data/models/system_config.dart';
import 'admin_ui.dart';

class RecognitionConfigBody extends StatelessWidget {
  const RecognitionConfigBody({
    super.key,
    required this.config,
    required this.model,
    required this.cosine,
    required this.gap,
    required this.liveness,
    required this.onChanged,
  });
  final SystemConfig config;
  final TextEditingController model, cosine, gap, liveness;
  final VoidCallback onChanged;
  bool get _allEmpty =>
      [model, cosine, gap, liveness].every((c) => c.text.trim().isEmpty);
  bool get _configured =>
      config.faceModelVersion?.isNotEmpty == true &&
      config.faceMaxCosineDistance != null &&
      config.faceMinDistanceGap != null &&
      config.livenessMinScore != null;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final formWidth =
            wide ? (constraints.maxWidth - 24) * .8 : constraints.maxWidth;
        return Wrap(spacing: 24, runSpacing: 20, children: [
          SizedBox(
              width: formWidth,
              child: AdminCard(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 456),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                              color: AppColors.warningSurface,
                              borderRadius: BorderRadius.circular(10)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Cần hiệu chỉnh trên dữ liệu thực tế trước khi bật nhận diện khuôn mặt.',
                                    style: AppTypography.label
                                        .copyWith(color: AppColors.warning)),
                                const SizedBox(height: 6),
                                Text(
                                    'Để trống cả bốn trường nghĩa là chưa cấu hình và kiosk sẽ chỉ dùng Mã QR.',
                                    style: AppTypography.caption.copyWith(
                                        color: AppColors.textPrimary)),
                              ]),
                        ),
                        const SizedBox(height: 24),
                        _field('face-model', 'Phiên bản mô hình', model,
                            (value) {
                          if (_allEmpty) return null;
                          if (value == null || value.trim().isEmpty) {
                            return 'Nhập phiên bản mô hình';
                          }
                          if (value.trim().length > 128) {
                            return 'Tối đa 128 ký tự';
                          }
                          return null;
                        }),
                        _field('face-cosine', 'Khoảng cách cosine tối đa',
                            cosine, (value) => _threshold(value, 2),
                            numeric: true),
                        _field(
                            'face-gap',
                            'Khoảng cách tối thiểu giữa hai ứng viên',
                            gap,
                            (value) => _threshold(value, 2),
                            numeric: true),
                        _field(
                            'face-liveness',
                            'Điểm kiểm tra người thật tối thiểu',
                            liveness,
                            (value) => _threshold(value, 1),
                            numeric: true),
                      ]),
                ),
              )),
          SizedBox(
            width: wide
                ? constraints.maxWidth - formWidth - 24
                : constraints.maxWidth,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppColors.neutralSurface,
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nhận diện khuôn mặt',
                        style: AppTypography.caption),
                    const SizedBox(height: 14),
                    Text(_configured ? 'Đã cấu hình' : 'Chưa cấu hình',
                        style: AppTypography.label.copyWith(
                            color: _configured
                                ? AppColors.success
                                : AppColors.textSecondary)),
                  ]),
            ),
          ),
        ]);
      });

  String? _threshold(String? value, num max) {
    if (_allEmpty) return null;
    final number = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
    return number == null || !number.isFinite || number < 0 || number > max
        ? 'Nhập số từ 0 đến $max'
        : null;
  }

  Widget _field(String key, String label, TextEditingController controller,
          FormFieldValidator<String> validator,
          {bool numeric = false}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AdminFieldLabel(label),
          TextFormField(
            key: ValueKey(key),
            controller: controller,
            keyboardType: numeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : null,
            decoration: const InputDecoration(
                hintText: 'Chưa cấu hình',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
            onChanged: (_) => onChanged(),
            validator: validator,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
        ]),
      );
}
