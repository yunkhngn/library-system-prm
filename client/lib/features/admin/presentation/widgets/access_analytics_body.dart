import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/admin_models.dart';
import 'admin_ui.dart';

/// ADM-15. All values, including method proportions, come from the same range.
class AccessAnalyticsBody extends StatelessWidget {
  const AccessAnalyticsBody(
      {super.key, required this.data, required this.hourly});

  final AccessAnalytics data;
  final bool hourly;
  static const exitColor = Color(0xFF91B4F8);

  String _number(num value) => NumberFormat.decimalPattern('vi').format(value);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final metricWidth =
              wide ? (constraints.maxWidth - 40) / 3 : constraints.maxWidth;
          final chartWidth =
              wide ? (constraints.maxWidth - 20) * .64 : constraints.maxWidth;
          final methodWidth = wide
              ? constraints.maxWidth - chartWidth - 20
              : constraints.maxWidth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(spacing: 20, runSpacing: 16, children: [
                SizedBox(
                  width: metricWidth,
                  child: AdminMetricCard(
                    label: 'Tổng lượt vào',
                    value: _number(data.totalCheckIns),
                  ),
                ),
                SizedBox(
                  width: metricWidth,
                  child: AdminMetricCard(
                    label: 'Tổng lượt ra',
                    value: _number(data.totalCheckOuts),
                  ),
                ),
                SizedBox(
                  width: metricWidth,
                  child: AdminMetricCard(
                    label: 'Thời gian ở trung bình',
                    value: data.averageStaySeconds == null
                        ? '—'
                        : Fmt.duration(Duration(
                            seconds: data.averageStaySeconds!.round())),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              Wrap(spacing: 20, runSpacing: 20, children: [
                SizedBox(
                  width: chartWidth,
                  child: AdminCard(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      height: 268,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AdminSectionTitle('Lượt vào và lượt ra'),
                          const SizedBox(height: 8),
                          Wrap(spacing: 24, children: [
                            _Legend('Lượt vào', AppColors.action),
                            const _Legend('Lượt ra', exitColor),
                          ]),
                          const SizedBox(height: 20),
                          Expanded(child: _chart()),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: methodWidth,
                  child: AdminCard(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 268),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AdminSectionTitle('Phương thức vào'),
                          const SizedBox(height: 28),
                          _method('Khuôn mặt', 'FACE', AppColors.action),
                          _method('Mã QR', 'QR', AppColors.success),
                          _method('Thủ công', 'MANUAL', AppColors.warning),
                          if (data.totalMethodCheckIns == 0)
                            Text('Chưa có lượt vào trong khoảng này.',
                                style: AppTypography.caption),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          );
        },
      );

  Widget _chart() {
    if (data.buckets.isEmpty ||
        data.buckets.every((b) => b.checkIns == 0 && b.checkOuts == 0)) {
      return Center(
          child: Text('Chưa có dữ liệu ra vào', style: AppTypography.caption));
    }
    final maxValue = data.buckets.fold<int>(
        1, (value, b) => math.max(value, math.max(b.checkIns, b.checkOuts)));
    return LayoutBuilder(builder: (context, constraints) {
      // Keep each bucket legible even for a long date range or hourly series.
      final width = math.max(constraints.maxWidth, data.buckets.length * 62.0);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final bucket in data.buckets)
                Expanded(
                  child: Tooltip(
                    message: '${Fmt.dateTime(bucket.startsAt)}\n'
                        'Lượt vào: ${_number(bucket.checkIns)}\n'
                        'Lượt ra: ${_number(bucket.checkOuts)}',
                    child: Semantics(
                      label: '${Fmt.dateTime(bucket.startsAt)}, '
                          '${bucket.checkIns} lượt vào, ${bucket.checkOuts} lượt ra',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _bar(bucket.checkIns, maxValue,
                                  constraints.maxHeight - 30, AppColors.action),
                              const SizedBox(width: 4),
                              _bar(bucket.checkOuts, maxValue,
                                  constraints.maxHeight - 30, exitColor),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hourly
                                ? Fmt.time(bucket.startsAt)
                                : Fmt.dayMonth(bucket.startsAt),
                            style: AppTypography.caption.copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _bar(int count, int maxValue, double height, Color color) => Container(
        width: 20,
        height: height * count / maxValue,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      );

  Widget _method(String label, String method, Color color) {
    final total = data.totalMethodCheckIns;
    final count = data.methodCount(method);
    final fraction = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(label, style: AppTypography.bodyM)),
          Text('${(fraction * 100).round()}%', style: AppTypography.label),
        ]),
        const SizedBox(height: 8),
        Semantics(
          label: '$label: $count trên $total lượt vào',
          child: AdminProgressBar(value: fraction, color: color),
        ),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: AppTypography.caption),
      ]);
}
