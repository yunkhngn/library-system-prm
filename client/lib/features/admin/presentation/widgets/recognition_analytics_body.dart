import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/admin_models.dart';
import 'admin_ui.dart';

/// ADM-16 reports recognition outcomes, not admission decisions or AI accuracy.
class RecognitionAnalyticsBody extends StatelessWidget {
  const RecognitionAnalyticsBody({super.key, required this.data});
  final RecognitionAnalytics data;

  String _number(num value) =>
      NumberFormat.decimalPattern('vi').format(value.round());

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth >= 780
            ? (constraints.maxWidth - 40) / 3
            : constraints.maxWidth >= 520
                ? (constraints.maxWidth - 20) / 2
                : constraints.maxWidth;
        final metrics = [
          ('Tổng lượt nhận diện', _number(data.totalAttempts)),
          ('Khớp danh tính', _number(data.matched)),
          ('Không thành công', _number(data.failed)),
          (
            'Tỷ lệ không thành công',
            data.totalAttempts == 0
                ? '—'
                : '${NumberFormat('0.0', 'vi').format(data.failed / data.totalAttempts * 100)}%'
          ),
          (
            'Thời gian xử lý P50',
            data.p50LatencyMs == null
                ? '—'
                : '${_number(data.p50LatencyMs!)} ms'
          ),
          (
            'P95',
            data.p95LatencyMs == null
                ? '—'
                : '${_number(data.p95LatencyMs!)} ms'
          ),
        ];
        final rows = [
          ('Khớp danh tính', data.matched, AppColors.success),
          ('Không khớp', data.outcomeCount('NO_MATCH'), AppColors.warning),
          (
            'Không đạt kiểm tra người thật',
            data.outcomeCount('LIVENESS_FAILED'),
            AppColors.error
          ),
          (
            'Ảnh chất lượng thấp',
            data.outcomeCount('LOW_QUALITY'),
            AppColors.action
          ),
          (
            'Dịch vụ không khả dụng',
            data.outcomeCount('SERVICE_UNAVAILABLE'),
            AppColors.textSecondary
          ),
        ];
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(spacing: 20, runSpacing: 20, children: [
                for (final metric in metrics)
                  SizedBox(
                      width: width,
                      child:
                          AdminMetricCard(label: metric.$1, value: metric.$2)),
              ]),
              const SizedBox(height: 40),
              AdminCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AdminSectionTitle('Kết quả nhận diện'),
                      const SizedBox(height: 18),
                      if (data.totalAttempts == 0)
                        const Padding(
                            padding: EdgeInsets.only(bottom: 18),
                            child: Text(
                                'Chưa có lượt nhận diện trong khoảng thời gian này.',
                                style: AppTypography.caption)),
                      for (final row in rows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: _outcome(row.$1, row.$2, row.$3,
                              constraints.maxWidth < 600),
                        ),
                    ],
                  )),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.infoSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '“Khớp danh tính” nghĩa là hệ thống nhận ra người quét; lượt ra vào vẫn có thể bị từ chối do quy định. Đây không phải độ chính xác của AI.',
                  style:
                      AppTypography.caption.copyWith(color: AppColors.action),
                ),
              ),
            ]);
      });

  Widget _outcome(String label, int count, Color color, bool compact) {
    final bar = Semantics(
      label: '$label: $count trên ${data.totalAttempts} lượt nhận diện',
      child: AdminProgressBar(
        value: data.totalAttempts == 0 ? 0 : count / data.totalAttempts,
        color: color,
        height: 11,
      ),
    );
    final text = Text(label,
        style: AppTypography.caption.copyWith(color: AppColors.textPrimary));
    final value = Text(_number(count),
        style: AppTypography.caption.copyWith(color: AppColors.textPrimary));
    if (compact) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: text),
          const SizedBox(width: 12),
          value
        ]),
        const SizedBox(height: 10),
        bar,
      ]);
    }
    return Row(children: [
      SizedBox(width: 268, child: text),
      Expanded(child: bar),
      const SizedBox(width: 18),
      SizedBox(width: 70, child: value),
    ]);
  }
}
