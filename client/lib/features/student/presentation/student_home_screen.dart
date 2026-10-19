import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../access/data/models/access_session.dart';
import '../application/student_home_provider.dart';

class StudentHomeScreen extends ConsumerStatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startRefresh();
  }

  void _startRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.invalidate(studentHomeProvider);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(studentHomeProvider);
      _startRefresh();
    } else {
      _refreshTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      ref.invalidate(studentHomeProvider);
      await ref.read(studentHomeProvider.future);
    } catch (_) {
      // The provider renders the retry state; RefreshIndicator must finish.
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: _refresh,
        child: ref.watch(studentHomeProvider).when(
              skipLoadingOnRefresh: false,
              loading: () => const _ScrollableState(child: LoadingState()),
              error: (error, _) => _ScrollableState(
                  child: ErrorState(
                message: error is ApiException
                    ? error.userMessage
                    : 'Không tải được dữ liệu. Vui lòng thử lại.',
                onRetry: () => ref.invalidate(studentHomeProvider),
              )),
              data: (data) => _HomeContent(
                  data: data, now: ref.watch(studentClockProvider)()),
            ),
      );
}

class _ScrollableState extends StatelessWidget {
  const _ScrollableState({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (_, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(height: constraints.maxHeight, child: child),
          ));
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.data, required this.now});
  final StudentHomeData data;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final name = data.user.fullName.trim().split(RegExp(r'\s+')).last;
    final current = data.status.currentSession;
    final inside = data.status.isInside;
    final elapsed =
        current == null ? Duration.zero : now.difference(current.checkInTime);
    final lastExit = data.recent
        .where((session) => session.checkOutTime != null)
        .fold<DateTime?>(
            null,
            (latest, session) =>
                latest == null || session.checkOutTime!.isAfter(latest)
                    ? session.checkOutTime
                    : latest);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 20, AppSpacing.md, 20),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Xin chào, $name',
                style: AppTypography.h2.copyWith(fontWeight: FontWeight.w700)),
            Text(Fmt.longDate(now),
                style: AppTypography.caption.copyWith(fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 20),
        _HomeCard(
          minHeight: 184,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            StatusBadge(
                label: inside ? 'Đang trong thư viện' : 'Ngoài thư viện',
                tone: inside ? BadgeTone.success : BadgeTone.neutral,
                icon: inside ? Icons.check : null),
            const SizedBox(height: AppSpacing.md),
            if (inside && current != null) ...[
              Text('Vào lúc ${Fmt.time(current.checkInTime)}',
                  style: AppTypography.h2
                      .copyWith(fontSize: 23, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                  'Đã ở ${Fmt.duration(elapsed.isNegative ? Duration.zero : elapsed)}',
                  style: AppTypography.bodyM
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                  [
                    if (current.checkInMethod != null)
                      current.checkInMethod!.label,
                    if (current.checkInKiosk != null) current.checkInKiosk!.name
                  ].join(' · '),
                  style: AppTypography.caption),
            ] else ...[
              Text(inside ? 'Đang cập nhật lượt vào' : 'Lần ra gần nhất',
                  style: AppTypography.label),
              const SizedBox(height: AppSpacing.sm),
              Text(
                  lastExit == null
                      ? 'Chưa có lượt ra gần đây'
                      : Fmt.dateTime(lastExit),
                  style: AppTypography.bodyL),
            ],
          ]),
        ),
        const SizedBox(height: 18),
        AppButton(
            label: 'Mở mã QR ra vào',
            icon: Icons.qr_code_2,
            size: AppButtonSize.mobile,
            alignment: MainAxisAlignment.start,
            expand: true,
            onPressed: () => context.go(Routes.studentQr)),
        const SizedBox(height: AppSpacing.md),
        _HomeCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Nhận diện khuôn mặt',
                style: AppTypography.bodyL
                    .copyWith(fontWeight: FontWeight.w600, height: 1.25)),
            const SizedBox(height: AppSpacing.sm),
            Text(
                data.user.faceEnrolled
                    ? 'Đã đăng ký — sẵn sàng ra vào bằng khuôn mặt'
                    : 'Chưa đăng ký — đăng ký để ra vào nhanh hơn',
                style: AppTypography.caption),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
                size: AppButtonSize.compact,
                label: data.user.faceEnrolled
                    ? 'Quản lý khuôn mặt'
                    : 'Đăng ký khuôn mặt',
                variant: AppButtonVariant.secondary,
                onPressed: () => context.go(Routes.studentFace)),
          ]),
        ),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
            header: true,
            child: InkWell(
              onTap: () => context.go(Routes.studentHistory),
              child: const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text('Lượt ra vào gần đây', style: AppTypography.h3)),
            )),
        if (data.recent.isEmpty)
          const _HomeCard(
              child: Text('Chưa có lượt ra vào trong 30 ngày gần đây.',
                  style: AppTypography.caption))
        else
          for (final session in data.recent) ...[
            _HistoryRow(session: session, now: now),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({required this.child, this.minHeight = 0});
  final Widget child;
  final double minHeight;

  @override
  Widget build(BuildContext context) => Card(
          child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: minHeight),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: child,
      ));
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.session, required this.now});
  final AccessSession session;
  final DateTime now;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: AppRadius.cardBorder,
          onTap: () => context.go(Routes.studentHistoryDetail(session.id)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: AppSpacing.sm),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    flex: 2,
                    child: Text(
                        Fmt.isSameVietnamDay(session.checkInTime, now)
                            ? 'Hôm nay'
                            : Fmt.date(session.checkInTime),
                        style: AppTypography.caption.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500))),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    flex: 4,
                    child: Text(
                        'Vào ${Fmt.time(session.checkInTime)}${session.isOpen ? ' · Đang mở' : ' → Ra ${Fmt.time(session.checkOutTime!)}'}',
                        style: AppTypography.caption.copyWith(fontSize: 11))),
              ]),
            ),
          ),
        ),
      );
}
