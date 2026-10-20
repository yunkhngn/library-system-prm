import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../application/admin_providers.dart';

import 'widgets/access_analytics_body.dart';
import 'widgets/recognition_analytics_body.dart';

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
              keepDataWhenInputsChange: false,
              data: (data) => RecognitionAnalyticsBody(data: data)),
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
}
