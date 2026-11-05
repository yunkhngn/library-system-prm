import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class AppSegment<T> {
  const AppSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Single-choice segmented control, e.g. "Tất cả / Sinh viên / Khách ngoài"
/// or "Danh sách / Lịch tuần". Segments size to their labels inside a
/// shared track; the selected one is raised.
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<AppSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.controlDesktop,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.neutralSurface,
        borderRadius: AppRadius.controlBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in segments)
            _Segment(
              segment: s,
              selected: s.value == selected,
              onTap: () {
                if (s.value != selected) onChanged(s.value);
              },
            ),
        ],
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment(
      {required this.segment, required this.selected, required this.onTap});

  final AppSegment<T> segment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.action : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.control - 2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.control - 2),
              boxShadow: selected && !AppColors.isDark
                  ? const [
                      BoxShadow(
                          color: Color(0x1A101828),
                          blurRadius: 3,
                          offset: Offset(0, 1)),
                    ]
                  : null,
              border: selected && AppColors.isDark
                  ? Border.all(color: AppColors.border)
                  : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (segment.icon != null) ...[
                Icon(segment.icon, size: 16, color: color),
                const SizedBox(width: 6),
              ],
              Text(
                segment.label,
                style: AppTypography.label.copyWith(
                  fontSize: 13,
                  color: selected ? AppColors.textPrimary : color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
