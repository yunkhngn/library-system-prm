import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../access/data/models/access_session.dart';
import '../application/student_history_providers.dart';

class StudentSessionDetailScreen extends ConsumerWidget {
  const StudentSessionDetailScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = studentSessionDetailProvider(sessionId);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(provider);
        try {
          await ref.read(provider.future);
        } catch (_) {/* Render provider error. */}
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.lg),
        children: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Text('Chi tiết lượt ra vào',
                  style:
                      AppTypography.h2.copyWith(fontWeight: FontWeight.w700))),
          const SizedBox(height: 18),
          ref.watch(provider).when(
                skipLoadingOnReload: false,
                skipLoadingOnRefresh: false,
                loading: () =>
                    const SizedBox(height: 240, child: LoadingState()),
                error: (error, _) => error
                            is ApiException &&
                        error.statusCode == 404
                    ? const EmptyState(
                        title: 'Không tìm thấy lượt ra vào',
                        message:
                            'Lượt ra vào không tồn tại hoặc bạn không có quyền xem.',
                        icon: Icons.history)
                    : ErrorState(
                        message: error is ApiException
                            ? error.userMessage
                            : 'Không tải được chi tiết. Vui lòng thử lại.',
                        onRetry: () => ref.invalidate(provider)),
                data: (session) => _SessionDetail(session: session),
              ),
          const SizedBox(height: AppSpacing.lg),
          Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                  label: 'Quay lại lịch sử',
                  variant: AppButtonVariant.link,
                  onPressed: () => context.go(Routes.studentHistory))),
        ],
      ),
    );
  }
}

class _SessionDetail extends StatelessWidget {
  const _SessionDetail({required this.session});
  final AccessSession session;

  @override
  Widget build(BuildContext context) {
    final automatic = session.autoCloseExplanation != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(
          child: Container(
              constraints: const BoxConstraints(minHeight: 130),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Fmt.date(session.checkInTime),
                        style: AppTypography.bodyM
                            .copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                        '${session.isOpen ? 'Đã ở ' : ''}${Fmt.duration(session.duration)}',
                        style: AppTypography.h2.copyWith(
                            fontSize: 23, fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppSpacing.sm),
                    StatusBadge(
                        label:
                            session.isOpen ? 'Đang trong thư viện' : 'Đã đóng',
                        tone: BadgeTone.success),
                  ]))),
      const SizedBox(height: AppSpacing.xl),
      Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
          child: Text('Lịch sử ghi nhận', style: AppTypography.h3)),
      _TimelineEvent(
        title: 'Ghi nhận vào',
        time: Fmt.time(session.checkInTime),
        method: session.checkInMethod?.label,
        lines: [
          if (session.checkInKiosk != null)
            'Kiosk: ${session.checkInKiosk!.name}',
          if (session.checkInBy != null)
            'Nhân viên: ${session.checkInBy!.fullName}',
          if (session.manualReason?.isNotEmpty == true)
            'Lý do: ${session.manualReason}',
        ],
        connect: true,
      ),
      _TimelineEvent(
        title: session.isOpen
            ? 'Chưa ghi nhận ra'
            : automatic
                ? 'Đóng lượt tự động'
                : 'Ghi nhận ra',
        time: session.checkOutTime == null
            ? null
            : Fmt.isSameVietnamDay(session.checkInTime, session.checkOutTime!)
                ? Fmt.time(session.checkOutTime!)
                : Fmt.dateTime(session.checkOutTime!),
        method:
            automatic || session.isOpen ? null : session.checkOutMethod?.label,
        pending: session.isOpen,
        lines: [
          if (session.isOpen) 'Lượt ra vào đang mở.',
          if (!session.isOpen && !automatic && session.checkOutKiosk != null)
            'Kiosk: ${session.checkOutKiosk!.name}',
          if (!session.isOpen && !automatic && session.checkOutBy != null)
            'Nhân viên: ${session.checkOutBy!.fullName}',
          if (!session.isOpen &&
              !automatic &&
              session.checkOutManualReason?.isNotEmpty == true)
            'Lý do: ${session.checkOutManualReason}',
        ],
      ),
      if (automatic)
        AppAlert(
            title: 'Lượt ra vào được đóng tự động',
            message: session.autoCloseExplanation),
    ]);
  }
}

class _TimelineEvent extends StatelessWidget {
  const _TimelineEvent(
      {required this.title,
      required this.time,
      required this.method,
      required this.lines,
      this.connect = false,
      this.pending = false});
  final String title;
  final String? time;
  final String? method;
  final List<String> lines;
  final bool connect;
  final bool pending;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
            width: 38,
            child: Column(children: [
              const SizedBox(height: AppSpacing.xs),
              Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                      color:
                          pending ? AppColors.neutralSurface : AppColors.action,
                      shape: BoxShape.circle,
                      border: pending
                          ? Border.all(color: AppColors.border, width: 2)
                          : null)),
              Expanded(
                  child: Center(
                      child: Container(
                          width: 2, color: connect ? AppColors.border : null))),
            ])),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xs, 0, AppSpacing.md, AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 100),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: AppTypography.label.copyWith(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        if (time != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text([time!, if (method != null) method!].join(' · '),
                              style: AppTypography.bodyM.copyWith(fontSize: 13))
                        ],
                        for (final line in lines) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(line, style: AppTypography.caption)
                        ],
                      ]),
                ))),
      ]));
}
