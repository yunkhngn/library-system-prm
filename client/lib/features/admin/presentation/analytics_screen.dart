import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../application/admin_providers.dart';
import '../data/admin_models.dart';
import 'widgets/admin_ui.dart';
import 'widgets/access_analytics_body.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(analyticsQueryProvider);
    return PageScaffold(
      title: _tab == 0 ? 'Thống kê ra vào' : 'Thống kê nhận diện khuôn mặt',
      subtitle:
          '${_tab == 0 ? 'Dữ liệu tổng hợp · ' : ''}${Fmt.dayMonth(query.from)} – ${Fmt.date(query.to.subtract(const Duration(microseconds: 1)))}${_tab == 1 ? ' · Không hiển thị ảnh khuôn mặt' : ''}',
      trailing: IconButton(
          onPressed: () => _pickRange(query),
          icon: const Icon(Icons.date_range_outlined),
          tooltip: 'Chọn khoảng thời gian'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 12, runSpacing: 10, children: [
          for (final tab in [(0, 'Ra vào'), (1, 'Nhận diện khuôn mặt')])
            SizedBox(
              width: tab.$1 == 0 ? 118 : 216,
              height: 38,
              child: _tab == tab.$1
                  ? FilledButton(onPressed: () {}, child: Text(tab.$2))
                  : OutlinedButton(
                      onPressed: () => setState(() => _tab = tab.$1),
                      child: Text(tab.$2)),
            ),
          if (_tab == 0)
            SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'DAY', label: Text('Theo ngày')),
                  ButtonSegment(value: 'HOUR', label: Text('Theo giờ'))
                ],
                selected: {
                  query.bucket
                },
                onSelectionChanged: (value) => ref
                    .read(analyticsQueryProvider.notifier)
                    .state = query.copyWith(bucket: value.first)),
        ]),
        const SizedBox(height: 16),
        if (_tab == 0)
          AsyncValueView(
              value: ref.watch(accessAnalyticsProvider),
              onRetry: () => ref.invalidate(accessAnalyticsProvider),
              keepDataWhenInputsChange: false,
              data: (data) => AccessAnalyticsBody(
                  data: data, hourly: query.bucket == 'HOUR'))
        else
          AsyncValueView(
              value: ref.watch(recognitionAnalyticsProvider),
              onRetry: () => ref.invalidate(recognitionAnalyticsProvider),
              data: _recognitionBody),
      ]),
    );
  }

  Future<void> _pickRange(AnalyticsQuery query) async {
    final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now(),
        initialDateRange: DateTimeRange(
            start: Fmt.toVietnam(query.from),
            end: Fmt.toVietnam(query.to.subtract(const Duration(days: 1)))));
    if (range == null) return;
    final exclusiveEnd =
        DateTime.utc(range.end.year, range.end.month, range.end.day)
            .subtract(const Duration(hours: 7))
            .add(const Duration(days: 1));
    ref.read(analyticsQueryProvider.notifier).state = query.copyWith(
        from: DateTime.utc(range.start.year, range.start.month, range.start.day)
            .subtract(const Duration(hours: 7)),
        to: exclusiveEnd,
        bucket: range.duration.inDays <= 2 ? query.bucket : 'DAY');
  }

  Widget _recognitionBody(RecognitionAnalytics data) {
    final rows = <(String, int, Color)>[
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
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth >= 780
          ? (constraints.maxWidth - 32) / 3
          : constraints.maxWidth >= 520
              ? (constraints.maxWidth - 16) / 2
              : constraints.maxWidth;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 16, runSpacing: 16, children: [
          SizedBox(
              width: width,
              child: AdminMetricCard(
                  label: 'Tổng lượt nhận diện',
                  value: _format(data.totalAttempts))),
          SizedBox(
              width: width,
              child: AdminMetricCard(
                  label: 'Khớp danh tính', value: _format(data.matched))),
          SizedBox(
              width: width,
              child: AdminMetricCard(
                  label: 'Không thành công', value: _format(data.failed))),
          SizedBox(
              width: width,
              child: AdminMetricCard(
                  label: 'Tỷ lệ không thành công',
                  value:
                      '${(data.failureRate * (data.failureRate <= 1 ? 100 : 1)).toStringAsFixed(1)}%')),
          SizedBox(
              width: width,
              child: AdminMetricCard(
                  label: 'Thời gian xử lý P50',
                  value: data.p50LatencyMs == null
                      ? '—'
                      : '${_format(data.p50LatencyMs)} ms')),
          SizedBox(
              width: width,
              child: AdminMetricCard(
                  label: 'P95',
                  value: data.p95LatencyMs == null
                      ? '—'
                      : '${_format(data.p95LatencyMs)} ms')),
        ]),
        const SizedBox(height: 28),
        AdminCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              const AdminSectionTitle('Kết quả nhận diện'),
              const SizedBox(height: 18),
              if (data.totalAttempts == 0)
                const Center(
                    child:
                        Text('Chưa có dữ liệu', style: AppTypography.caption)),
              for (final row in rows)
                Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(children: [
                      SizedBox(
                          width: 210,
                          child: Text(row.$1,
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textPrimary))),
                      Expanded(
                          child: AdminProgressBar(
                              value: data.totalAttempts == 0
                                  ? 0
                                  : row.$2 / data.totalAttempts,
                              color: row.$3,
                              height: 12)),
                      const SizedBox(width: 14),
                      SizedBox(
                          width: 50,
                          child: Text(_format(row.$2),
                              style: AppTypography.caption)),
                    ])),
            ])),
      ]);
    });
  }

  String _format(num? value) =>
      NumberFormat.decimalPattern('vi').format((value ?? 0).round());
}
