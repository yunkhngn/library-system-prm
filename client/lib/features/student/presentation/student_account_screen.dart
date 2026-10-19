import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../auth/data/models/user.dart';
import '../../auth/presentation/logout_dialog.dart';
import '../application/student_account_provider.dart';

class StudentAccountScreen extends ConsumerWidget {
  const StudentAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(studentAccountProvider);
          try {
            await ref.read(studentAccountProvider.future);
          } catch (_) {/* Show provider error. */}
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.lg),
          children: [
            Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: Text('Tài khoản',
                    style: AppTypography.h2
                        .copyWith(fontWeight: FontWeight.w700))),
            const SizedBox(height: AppSpacing.lg),
            AsyncValueView<User>(
              value: ref.watch(studentAccountProvider),
              keepDataWhenInputsChange: false,
              onRetry: () => ref.invalidate(studentAccountProvider),
              data: (user) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                        child: Container(
                      constraints: const BoxConstraints(minHeight: 126),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                      radius: 26,
                                      backgroundColor: AppColors.infoSurface,
                                      child: Text(user.initials,
                                          style: AppTypography.bodyL.copyWith(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.action))),
                                  const SizedBox(width: 14),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(user.fullName,
                                            style: AppTypography.bodyL.copyWith(
                                                fontWeight: FontWeight.w600,
                                                height: 1.25)),
                                        const SizedBox(height: AppSpacing.sm),
                                        Text(
                                            '${user.code} · ${user.role.label}',
                                            style: AppTypography.caption),
                                      ])),
                                ]),
                            const SizedBox(height: AppSpacing.md),
                            Text(user.email, style: AppTypography.caption),
                          ]),
                    )),
                    const SizedBox(height: AppSpacing.lg),
                    _AccountSetting(
                        title: 'Bảo mật',
                        detail: 'Đổi mật khẩu',
                        onTap: () => context.go(Routes.studentChangePassword)),
                    const SizedBox(height: 14),
                    _AccountSetting(
                        title: 'Nhận diện khuôn mặt',
                        detail:
                            user.faceEnrolled ? 'Đã đăng ký' : 'Chưa đăng ký',
                        onTap: () => context.go(Routes.studentFace)),
                    const SizedBox(height: 14),
                    _AccountSetting(
                        title: 'Quy định thư viện',
                        detail: 'Giờ mở cửa và thông tin thư viện',
                        onTap: () => context.go(Routes.studentRules)),
                  ]),
            ),
            const SizedBox(height: AppSpacing.lg),
            Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                    label: 'Đăng xuất',
                    icon: Icons.logout,
                    variant: AppButtonVariant.ghost,
                    onPressed: () => confirmLogout(context, ref))),
          ],
        ),
      );
}

class _AccountSetting extends StatelessWidget {
  const _AccountSetting(
      {required this.title, required this.detail, required this.onTap});
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
          child: InkWell(
        borderRadius: AppRadius.cardBorder,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppTypography.label),
            const SizedBox(height: AppSpacing.xs),
            Text(detail, style: AppTypography.caption),
          ]),
        ),
      ));
}
