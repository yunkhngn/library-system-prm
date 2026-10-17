import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../application/password_policy.dart';

/// 4-segment strength bar plus a live checklist of [PasswordRule]s.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.controller});

  final TextEditingController controller;

  static Color _colorFor(PasswordStrength strength) => switch (strength) {
        PasswordStrength.empty => AppColors.border,
        PasswordStrength.weak => AppColors.error,
        PasswordStrength.fair => AppColors.warning,
        PasswordStrength.good => AppColors.action,
        PasswordStrength.strong => AppColors.success,
      };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final password = value.text;
        final strength = PasswordPolicy.strengthOf(password);
        final satisfied = PasswordPolicy.satisfiedRules(password);
        final color = _colorFor(strength);

        return Semantics(
          label: 'Độ mạnh mật khẩu: ${strength == PasswordStrength.empty ? 'chưa nhập' : strength.label}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  for (var i = 1; i <= 4; i++) ...[
                    if (i > 1) const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= strength.level ? color : AppColors.border,
                          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 72,
                    child: Text(
                      strength.label,
                      textAlign: TextAlign.end,
                      style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final rule in PasswordRule.values)
                    _RuleItem(label: rule.label, met: satisfied.contains(rule)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RuleItem extends StatelessWidget {
  const _RuleItem({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final color = met ? AppColors.success : AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(met ? Icons.check_circle : Icons.radio_button_unchecked, size: 14, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTypography.caption.copyWith(color: color)),
      ],
    );
  }
}
