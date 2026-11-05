import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/app_alert.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_segmented.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/labeled_value.dart';
import '../../shared/widgets/pagination_bar.dart';
import '../../shared/widgets/search_field.dart';
import '../../shared/widgets/side_sheet.dart';
import '../../shared/widgets/status_badge.dart';

/// `/dev/components` — every shared component, for comparison with Figma P1.
class ComponentGalleryScreen extends StatelessWidget {
  const ComponentGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Foundations & Shared components', style: AppTypography.h1),
            const SizedBox(height: AppSpacing.lg),
            _Section('01 Màu sắc', [
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  _Swatch('Primary / Navy', AppColors.navy),
                  _Swatch('Primary / Action', AppColors.action),
                  _Swatch('Page background', AppColors.background),
                  _Swatch('Surface', AppColors.surface),
                  _Swatch('Text / Primary', AppColors.textPrimary),
                  _Swatch('Text / Secondary', AppColors.textSecondary),
                  _Swatch('Border', AppColors.border),
                  _Swatch('Success', AppColors.success),
                  _Swatch('Warning', AppColors.warning),
                  _Swatch('Error', AppColors.error),
                ],
              ),
            ]),
            _Section('02 Kiểu chữ · Be Vietnam Pro', [
              Text('Đăng ký nhận diện khuôn mặt', style: AppTypography.display),
              Text('Số người đang trong thư viện', style: AppTypography.h1),
              Text('Xác nhận hủy phân công', style: AppTypography.h2),
              Text('Dữ liệu đã được cập nhật', style: AppTypography.h3),
              Text('Nguyễn Thị Huyền · Vui lòng quay đầu sang trái', style: AppTypography.bodyL),
              Text('Thứ Ba, 13/10/2026 · Đang kết nối trực tiếp', style: AppTypography.bodyM),
            ]),
            _Section('03 Nút bấm', [
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppButton(label: 'Primary', onPressed: () {}),
                  AppButton(label: 'Secondary', variant: AppButtonVariant.secondary, onPressed: () {}),
                  AppButton(label: 'Ghost', variant: AppButtonVariant.ghost, onPressed: () {}),
                  AppButton(label: 'Destructive', variant: AppButtonVariant.destructive, onPressed: () {}),
                  AppButton(label: 'Link', variant: AppButtonVariant.link, onPressed: () {}),
                  const AppButton(label: 'Disabled', onPressed: null),
                  AppButton(label: 'Đang xử lý', loading: true, onPressed: () {}),
                ],
              ),
            ]),
            const _Section('04 Trạng thái & phương thức', [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  StatusBadge.active(),
                  StatusBadge.inside(),
                  StatusBadge.nearCapacity(),
                  StatusBadge.locked(),
                  StatusBadge.disconnected(),
                  StatusBadge.outside(),
                  StatusBadge.face(),
                  StatusBadge.qr(),
                  StatusBadge.manual(),
                  StatusBadge.cancelled(),
                  StatusBadge.today(),
                ],
              ),
            ]),
            const _Section('06 Danh sách & điều hướng', [_ListControlsDemo()]),
            const _Section('05 Trường nhập liệu & thông báo', [
              SizedBox(
                width: 360,
                child: AppTextField(
                  label: 'Mã tài khoản hoặc email',
                  hint: 'VD: SV001 hoặc ten@example.edu.vn',
                  helper: 'Trợ giúp: Nhập mã tài khoản hoặc email đã được cấp',
                ),
              ),
              SizedBox(height: AppSpacing.md),
              SizedBox(width: 360, child: AppTextField(label: 'Mật khẩu', obscure: true)),
              SizedBox(height: AppSpacing.md),
              AppAlert(title: 'Thông tin', message: 'Thay đổi được lưu sau khi bạn xác nhận.'),
              SizedBox(height: AppSpacing.sm),
              AppAlert(
                tone: AlertTone.error,
                title: 'Không tải được dữ liệu',
                message: 'Kiểm tra kết nối mạng và thử lại.',
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ListControlsDemo extends StatefulWidget {
  const _ListControlsDemo();

  @override
  State<_ListControlsDemo> createState() => _ListControlsDemoState();
}

class _ListControlsDemoState extends State<_ListControlsDemo> {
  String _kind = 'all';
  int _page = 0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppSearchField(
              hint: 'Tìm theo tên hoặc mã',
              onChanged: (q) => setState(() => _query = q),
            ),
            AppSegmented<String>(
              segments: const [
                AppSegment(value: 'all', label: 'Tất cả'),
                AppSegment(value: 'student', label: 'Sinh viên'),
                AppSegment(value: 'visitor', label: 'Khách ngoài'),
              ],
              selected: _kind,
              onChanged: (v) => setState(() => _kind = v),
            ),
            AppButton(
              label: 'Mở side sheet',
              variant: AppButtonVariant.secondary,
              onPressed: () => showSideSheet(
                context,
                title: 'Chi tiết lượt ra vào',
                builder: (_) => const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LabeledValue(label: 'Họ và tên', value: 'Nguyễn Thị Huyền'),
                    LabeledValue(label: 'Mã', value: 'SV001'),
                    LabeledValue(label: 'Phương thức vào', child: StatusBadge.qr()),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Từ khóa (sau debounce): "${_query.isEmpty ? '—' : _query}" · Bộ lọc: $_kind',
          style: AppTypography.caption,
        ),
        PaginationBar(
          page: _page,
          size: 20,
          totalElements: 187,
          onPageChanged: (p) => setState(() => _page = p),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.h3),
              const SizedBox(height: AppSpacing.md),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.color);

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final hex = '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    return SizedBox(
      width: 200,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: AppRadius.controlBorder,
              border: Border.all(color: AppColors.border),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.label),
                Text(hex, style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
