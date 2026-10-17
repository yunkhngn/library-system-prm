import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_dialog.dart';
import '../application/session_controller.dart';

/// AUTH-06 — Logout confirmation.
Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
  final confirmed = await showConfirmDialog(
    context,
    title: 'Đăng xuất',
    message: 'Bạn có chắc muốn đăng xuất khỏi tài khoản này?',
    confirmLabel: 'Đăng xuất',
  );
  if (confirmed) await ref.read(sessionControllerProvider.notifier).logout();
}
