import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// The text-only app bar and bottom tabs follow the STU Figma frames.
class StudentShell extends StatelessWidget {
  const StudentShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    const tabs = [
      (Routes.studentHome, 'Trang chủ'),
      (Routes.studentQr, 'Mã QR'),
      (Routes.studentHistory, 'Lịch sử'),
      (Routes.studentAccount, 'Tài khoản'),
    ];
    final selected = path.startsWith(Routes.studentHistory)
        ? 2
        : path == Routes.studentQr
            ? 1
            : path == Routes.studentAccount || path == Routes.studentFace
                ? 3
                : 0;
    final title = path == Routes.studentFace
        ? 'Nhận diện khuôn mặt'
        : path == Routes.studentQr
            ? 'Mã QR cá nhân'
            : path.startsWith('${Routes.studentHistory}/')
                ? 'Chi tiết lượt ra vào'
                : path == Routes.studentHistory
                    ? 'Lịch sử ra vào'
                    : tabs[selected].$2;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppSizes.compactBreakpoint),
            child: Column(children: [
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 72),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border:
                        Border(bottom: BorderSide(color: AppColors.border))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Library Access',
                          style: AppTypography.h3.copyWith(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: AppSpacing.xs),
                      Text(title, style: AppTypography.caption),
                    ]),
              ),
              Expanded(child: child),
              Container(
                decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border))),
                child: SafeArea(
                    top: false,
                    child: SizedBox(
                      height: 74,
                      child: Row(
                          children: List.generate(
                              tabs.length,
                              (index) => Expanded(
                                    child: Semantics(
                                      selected: index == selected,
                                      child: TextButton(
                                        onPressed: () =>
                                            context.go(tabs[index].$1),
                                        style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(0, 74),
                                            shape:
                                                const RoundedRectangleBorder()),
                                        child: Text(tabs[index].$2,
                                            style: AppTypography.caption
                                                .copyWith(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: selected == index
                                                        ? AppColors.action
                                                        : AppColors
                                                            .textSecondary)),
                                      ),
                                    ),
                                  ))),
                    )),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
