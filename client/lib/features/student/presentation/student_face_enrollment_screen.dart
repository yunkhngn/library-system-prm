import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/face_enrollment_controller.dart';
import 'widgets/face_capture_camera.dart';

class StudentFaceEnrollmentScreen extends ConsumerStatefulWidget {
  const StudentFaceEnrollmentScreen({super.key});
  @override
  ConsumerState<StudentFaceEnrollmentScreen> createState() =>
      _StudentFaceEnrollmentScreenState();
}

class _StudentFaceEnrollmentScreenState
    extends ConsumerState<StudentFaceEnrollmentScreen> {
  bool _readingPolicy = false, _accepted = false, _selecting = false;
  String? _selectionError;

  Future<void> _choosePhotos() async {
    if (_selecting) return;
    final snapshot = ref.read(faceEnrollmentControllerProvider);
    if (!snapshot.consented || snapshot.busy || snapshot.needsReconcile) return;
    setState(() {
      _selecting = true;
      _selectionError = null;
    });
    try {
      final files = await openFiles(acceptedTypeGroups: const [
        XTypeGroup(
            label: 'JPEG/PNG',
            extensions: ['jpg', 'jpeg', 'png'],
            mimeTypes: ['image/jpeg', 'image/png'],
            uniformTypeIdentifiers: ['public.jpeg', 'public.png'])
      ]);
      if (!mounted || files.isEmpty) return;
      if (files.length + snapshot.photos.length > snapshot.policy!.maxImages) {
        throw FormatException(
            'Chỉ chọn tối đa ${snapshot.policy!.maxImages} ảnh.');
      }
      for (final file in files) {
        if (await file.length() > snapshot.policy!.maxImageBytes) {
          throw const FormatException('Mỗi ảnh không được vượt quá 5 MiB.');
        }
      }
      final images = await Future.wait(files.map((file) => file.readAsBytes()));
      if (mounted) {
        await ref
            .read(faceEnrollmentControllerProvider.notifier)
            .addPhotos(images);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _selectionError = error is FormatException
            ? error.message.toString()
            : 'Không chọn được ảnh. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(faceEnrollmentControllerProvider);
    final controller = ref.read(faceEnrollmentControllerProvider.notifier);
    ref.listen(faceEnrollmentControllerProvider, (previous, next) {
      if (previous?.policy?.version != next.policy?.version ||
          (previous?.consented == true && !next.consented)) {
        _accepted = false;
        _readingPolicy = false;
      }
    });
    if (state.loading) return const LoadingState();
    if (state.policy == null) {
      return ErrorState(
          message: state.message ?? 'Không tải được chính sách đăng ký.',
          onRetry: controller.load);
    }
    final policy = state.policy!;
    return ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.lg),
        children: [
          Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: Text('Nhận diện khuôn mặt',
                  style:
                      AppTypography.h2.copyWith(fontWeight: FontWeight.w700))),
          const SizedBox(height: AppSpacing.md),
          Card(
              child: Container(
                  constraints: const BoxConstraints(minHeight: 150),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppColors.infoSurface,
                                  child: Icon(Icons.face_outlined,
                                      color: AppColors.action)),
                              const SizedBox(width: 14),
                              Expanded(
                                  child: Text(
                                      state.enrollment?.isEnrolled == true
                                          ? 'Đã có đăng ký khuôn mặt'
                                          : 'Đăng ký khuôn mặt',
                                      style: AppTypography.h3
                                          .copyWith(fontSize: 17))),
                            ]),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                            state.enrollment?.isEnrolled == true
                                ? 'Đăng ký lại chỉ thay dữ liệu cũ sau khi bộ ảnh mới hợp lệ.'
                                : 'Giúp ghi nhận ra vào nhanh hơn tại kiosk.',
                            style:
                                AppTypography.caption.copyWith(fontSize: 13)),
                      ]))),
          const SizedBox(height: AppSpacing.lg),
          if (state.success) ...[
            const AppAlert(
                title: 'Đăng ký khuôn mặt thành công',
                message: 'Máy chủ đã xác nhận lưu bộ dữ liệu đăng ký.',
                tone: AlertTone.success),
            const SizedBox(height: AppSpacing.md),
            AppButton(
                label: 'Về tài khoản',
                expand: true,
                onPressed: () => context.go(Routes.studentAccount)),
          ] else ...[
            if (state.message != null || _selectionError != null) ...[
              AppAlert(
                  title: state.needsReconcile
                      ? 'Cần kiểm tra trạng thái đăng ký'
                      : 'Thông tin đăng ký',
                  message: _selectionError ?? state.message,
                  tone: AlertTone.warning),
              if (state.enrollment?.isEnrolled == true)
                Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                        'Đăng ký hiện có vẫn được giữ khi gửi bộ ảnh mới thất bại.',
                        style: AppTypography.caption)),
              const SizedBox(height: AppSpacing.md),
            ],
            if (state.needsReconcile)
              AppButton(
                  label: 'Kiểm tra trạng thái',
                  expand: true,
                  loading: state.busy,
                  onPressed: controller.reconcile)
            else if (!state.consented) ...[
              if (_readingPolicy)
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(policy.title, style: AppTypography.h3),
                              const SizedBox(height: AppSpacing.sm),
                              Text(policy.content, style: AppTypography.bodyM),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                  'Cần ${policy.minImages}–${policy.maxImages} ảnh JPEG/PNG, mỗi ảnh tối đa ${(policy.maxImageBytes / 1048576).round()} MiB. Ảnh xem trước chỉ được giữ tạm trong phiên đăng ký.',
                                  style: AppTypography.caption),
                              CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                      'Tôi đồng ý với chính sách xử lý khuôn mặt.'),
                                  value: _accepted,
                                  onChanged: state.busy
                                      ? null
                                      : (value) => setState(
                                          () => _accepted = value ?? false)),
                            ])))
              else
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(children: [
                          Container(
                              height: 180,
                              decoration: BoxDecoration(
                                  color: AppColors.textPrimary,
                                  borderRadius: AppRadius.cardBorder),
                              child: Center(
                                  child: Container(
                                      width: 126,
                                      height: 140,
                                      decoration: BoxDecoration(
                                          color: AppColors.textSecondary
                                              .withValues(alpha: 0.5),
                                          borderRadius:
                                              BorderRadius.circular(62))))),
                          const SizedBox(height: AppSpacing.md),
                          Text('Đưa khuôn mặt vào giữa khung',
                              style: AppTypography.label),
                          const SizedBox(height: AppSpacing.sm),
                        ]))),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                  label:
                      _readingPolicy ? 'Đồng ý và tiếp tục' : 'Bắt đầu đăng ký',
                  expand: true,
                  size: AppButtonSize.mobile,
                  alignment: MainAxisAlignment.start,
                  loading: state.busy,
                  onPressed: _readingPolicy
                      ? (_accepted ? controller.consent : null)
                      : () => setState(() {
                            _readingPolicy = true;
                            _accepted = false;
                          })),
              const SizedBox(height: AppSpacing.md),
              Text('Chỉ tiếp tục khi bạn đồng ý với quy trình nhận diện.',
                  style: AppTypography.caption),
            ] else ...[
              if (state.busy)
                const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: LinearProgressIndicator()),
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: ref.watch(faceCameraBuilderProvider)(
                          context,
                          (bytes) => controller.addPhotos([bytes]),
                          policy.maxImageBytes,
                          !state.busy &&
                              !_selecting &&
                              state.photos.length < policy.maxImages))),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                  label: 'Chọn ảnh từ thiết bị',
                  icon: Icons.photo_library_outlined,
                  variant: AppButtonVariant.secondary,
                  loading: _selecting,
                  onPressed:
                      state.busy || state.photos.length >= policy.maxImages
                          ? null
                          : _choosePhotos),
              const SizedBox(height: AppSpacing.md),
              Text(
                  'Ảnh tạm thời: ${state.photos.length}/${policy.maxImages} (cần ít nhất ${policy.minImages})',
                  style: AppTypography.label),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (var i = 0; i < state.photos.length; i++)
                      SizedBox(
                          width: 96,
                          child: Column(children: [
                            ClipRRect(
                                borderRadius: AppRadius.controlBorder,
                                child: Image.memory(state.photos[i].bytes,
                                    width: 96,
                                    height: 96,
                                    fit: BoxFit.cover,
                                    cacheWidth: 192,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.broken_image_outlined))),
                            IconButton(
                                tooltip: 'Xóa ảnh ${i + 1}',
                                onPressed: state.busy || _selecting
                                    ? null
                                    : () => controller.removePhoto(i),
                                icon: const Icon(Icons.close)),
                          ]))
                  ]),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                  label: state.enrollment?.isEnrolled == true
                      ? 'Thay bộ ảnh đăng ký'
                      : 'Gửi đăng ký',
                  expand: true,
                  size: AppButtonSize.mobile,
                  loading: state.busy,
                  onPressed: state.canSubmit && !_selecting
                      ? controller.submit
                      : null),
              const SizedBox(height: AppSpacing.sm),
              Text(
                  'Chụp rõ, đủ sáng, mỗi ảnh chỉ có một người. Máy chủ sẽ kiểm tra bộ ảnh sau khi gửi.',
                  style: AppTypography.caption),
            ],
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
              label: 'Sử dụng mã QR',
              variant: AppButtonVariant.link,
              onPressed: () => context.go(Routes.studentQr)),
        ]);
  }
}
