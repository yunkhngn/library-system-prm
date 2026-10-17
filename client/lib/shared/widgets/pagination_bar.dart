import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// "Hiển thị 1–20 trên 187" with previous/next page buttons.
/// [page] is zero-based, matching the backend `*Page` schemas.
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.onPageChanged,
  });

  final int page;
  final int size;
  final int totalElements;
  final ValueChanged<int> onPageChanged;

  int get _totalPages => totalElements == 0 ? 1 : (totalElements / size).ceil();

  @override
  Widget build(BuildContext context) {
    final first = totalElements == 0 ? 0 : page * size + 1;
    final last = (page * size + size).clamp(0, totalElements);
    final hasPrevious = page > 0;
    final hasNext = page + 1 < _totalPages;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Hiển thị $first–$last trên $totalElements',
              style: AppTypography.bodyM.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Text(
            'Trang ${page + 1}/$_totalPages',
            style: AppTypography.bodyM.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: 'Trang trước',
            icon: const Icon(Icons.chevron_left),
            onPressed: hasPrevious ? () => onPageChanged(page - 1) : null,
          ),
          IconButton(
            tooltip: 'Trang sau',
            icon: const Icon(Icons.chevron_right),
            onPressed: hasNext ? () => onPageChanged(page + 1) : null,
          ),
        ],
      ),
    );
  }
}
