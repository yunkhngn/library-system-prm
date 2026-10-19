import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/state_views.dart';
import '../../system_config/data/models/system_config.dart';
import '../application/student_rules_provider.dart';

class StudentRulesScreen extends ConsumerWidget {
  const StudentRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(studentRulesProvider);
          try {
            await ref.read(studentRulesProvider.future);
          } catch (_) {/* Render error state. */}
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text('Quy định thư viện',
                    style: AppTypography.h2
                        .copyWith(fontWeight: FontWeight.w700))),
            const SizedBox(height: 22),
            ref.watch(studentRulesProvider).when(
                  skipLoadingOnRefresh: false,
                  loading: () => const Padding(
                      padding: EdgeInsets.all(48), child: LoadingState()),
                  error: (error, _) => ErrorState(
                      message: error is ApiException
                          ? error.userMessage
                          : 'Không tải được quy định thư viện.',
                      onRetry: () => ref.invalidate(studentRulesProvider)),
                  data: (config) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Rule(title: 'Giờ mở cửa', value: _hours(config)),
                        const SizedBox(height: 18),
                        _Rule(
                            title: 'Sức chứa tối đa',
                            value: '${config.maxCapacity} người'),
                        const SizedBox(height: 18),
                        // The server issues QR tokens with JwtService.QR_TOKEN_VALIDITY_SECONDS = 30.
                        const _Rule(
                            title: 'Mã QR cá nhân',
                            value: 'Có hiệu lực trong 30 giây'),
                        const SizedBox(height: 18),
                        _Rule(
                            title: 'Khoảng cách giữa hai lần quét',
                            value: '${config.scanCooldownSeconds} giây'),
                        const SizedBox(height: 32),
                        Container(
                            constraints: const BoxConstraints(minHeight: 96),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                                color: AppColors.infoSurface,
                                borderRadius: BorderRadius.circular(10)),
                            child: Text(
                                'Ngoài giờ mở cửa vẫn có thể ghi nhận ra, nhưng không thể ghi nhận vào.',
                                style: AppTypography.caption.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.action))),
                      ]),
                ),
          ],
        ),
      );

  String _hours(SystemConfig config) {
    final first = config.slotFor(1);
    if (first != null &&
        List.generate(7, (i) => config.slotFor(i + 1)).every((slot) =>
            slot != null &&
            slot.opensAt == first.opensAt &&
            slot.closesAt == first.closesAt)) {
      return '${first.opensAt} – ${first.closesAt} mỗi ngày';
    }
    return List.generate(7, (i) {
      final slot = config.slotFor(i + 1);
      return '${Fmt.weekdayName(i + 1)}: ${slot == null ? 'Đóng cửa' : '${slot.opensAt} – ${slot.closesAt}'}';
    }).join('\n');
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.title, required this.value});
  final String title, value;
  @override
  Widget build(BuildContext context) => Card(
          child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: AppTypography.label.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.caption.copyWith(fontSize: 13)),
        ]),
      ));
}
