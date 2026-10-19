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
          '${Fmt.dayMonth(query.from)} – ${Fmt.date(query.to.subtract(const Duration(microseconds: 1)))}${_tab == 1 ? ' · Không hiển thị ảnh khuôn mặt' : ''}',
      trailing: IconButton(
          onPressed: () => _pickRange(query),
          icon: const Icon(Icons.date_range_outlined),
          tooltip: 'Chọn khoảng thời gian'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 12, runSpacing: 10, children: [
          SegmentedButton<int>(segments: const [
            ButtonSegment(value: 0, label: Text('Ra vào')),
            ButtonSegment(value: 1, label: Text('Nhận diện khuôn mặt'))
          ], selected: {
            _tab
          }, onSelectionChanged: (value) => setState(() => _tab = value.first)),
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
              data: _accessBody)
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
            start: query.from,
            end: query.to.subtract(const Duration(days: 1))));
    if (range == null) return;
    final exclusiveEnd =
        DateTime(range.end.year, range.end.month, range.end.day)
            .add(const Duration(days: 1));
    ref.read(analyticsQueryProvider.notifier).state = query.copyWith(
        from: DateTime(range.start.year, range.start.month, range.start.day),
        to: exclusiveEnd,
        bucket: range.duration.inDays <= 2 ? query.bucket : 'DAY');
  }

  Widget _accessBody(AccessAnalytics data) =>
      LayoutBuilder(builder: (context, constraints) {
        final metricWidth = constraints.maxWidth >= 760
            ? (constraints.maxWidth - 32) / 3
            : constraints.maxWidth;
        final totalMethods = data.totalMethodCheckIns;
        final chartMax = data.buckets.fold<int>(1, (currentMax, bucket) {
          final bucketMax = bucket.checkIns > bucket.checkOuts
              ? bucket.checkIns
              : bucket.checkOuts;
          return bucketMax > currentMax ? bucketMax : currentMax;
        });
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(spacing: 16, runSpacing: 16, children: [
                SizedBox(
                    width: metricWidth,
                    child: AdminMetricCard(
                        label: 'Tổng lượt vào',
                        value: _format(data.totalCheckIns))),
                SizedBox(
                    width: metricWidth,
                    child: AdminMetricCard(
                        label: 'Tổng lượt ra',
                        value: _format(data.totalCheckOuts))),
                SizedBox(
                    width: metricWidth,
                    child: AdminMetricCard(
                        label: 'Thời gian ở trung bình',
                        value: data.averageStaySeconds == null
                            ? '—'
                            : Fmt.duration(Duration(
                                seconds: data.averageStaySeconds!.round())))),
              ]),
              const SizedBox(height: 16),
              Wrap(spacing: 16, runSpacing: 16, children: [
                SizedBox(
                    width: constraints.maxWidth >= 760
                        ? constraints.maxWidth * .62
                        : constraints.maxWidth,
                    child: AdminCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const AdminSectionTitle('Lượt vào và lượt ra'),
                          const SizedBox(height: 22),
                          SizedBox(
                              height: 180,
                              child: data.buckets.isEmpty
                                  ? const Center(
                                      child: Text('Chưa có dữ liệu',
                                          style: AppTypography.caption))
                                  : Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                          for (final bucket in data.buckets)
                                            Expanded(
                                                child:
                                                    _barGroup(bucket, chartMax))
                                        ])),
                        ]))),
                SizedBox(
                    width: constraints.maxWidth >= 760
                        ? constraints.maxWidth * .34
                        : constraints.maxWidth,
                    child: AdminCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          const AdminSectionTitle('Phương thức vào'),
                          const SizedBox(height: 24),
                          _method('Khuôn mặt', data.methodCount('FACE'),
                              totalMethods, AppColors.action),
                          _method('Mã QR', data.methodCount('QR'), totalMethods,
                              AppColors.success),
                          _method('Thủ công', data.methodCount('MANUAL'),
                              totalMethods, AppColors.warning),
                        ]))),
              ]),
            ]);
      });

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

  Widget _barGroup(AccessBucket bucket, int chartMax) {
    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
                width: 18,
                height: 135 * bucket.checkIns / chartMax,
                decoration: BoxDecoration(
                    color: AppColors.action,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 4),
            Container(
                width: 18,
                height: 135 * bucket.checkOuts / chartMax,
                decoration: BoxDecoration(
                    color: const Color(0xFF91B4F8),
                    borderRadius: BorderRadius.circular(4))),
          ]),
      const SizedBox(height: 8),
      Text(Fmt.dayMonth(bucket.startsAt),
          maxLines: 1, style: AppTypography.caption.copyWith(fontSize: 10)),
    ]);
  }

  Widget _method(String label, int count, int total, Color color) {
    final value = total == 0 ? 0.0 : count / total;
    return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(children: [
          Row(children: [
            Expanded(child: Text(label, style: AppTypography.bodyM)),
            Text('${(value * 100).round()}%', style: AppTypography.label)
          ]),
          const SizedBox(height: 8),
          AdminProgressBar(value: value, color: color)
        ]));
  }

  String _format(num? value) =>
      NumberFormat.decimalPattern('vi').format((value ?? 0).round());
}
