import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Be Vietnam Pro type scale. Line height ~1.5 for body text keeps
/// Vietnamese diacritics from clipping. Colors follow the active theme.
abstract final class AppTypography {
  static const fontFamily = 'BeVietnamPro';

  static TextStyle _style(double size, FontWeight weight, double height,
          Color color) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: color,
      );

  static TextStyle get display =>
      _style(56, FontWeight.w700, 1.25, AppColors.textPrimary);
  static TextStyle get h1 =>
      _style(30, FontWeight.w600, 1.3, AppColors.textPrimary);
  static TextStyle get h2 =>
      _style(24, FontWeight.w600, 1.35, AppColors.textPrimary);
  static TextStyle get h3 =>
      _style(18, FontWeight.w600, 1.4, AppColors.textPrimary);
  static TextStyle get bodyL =>
      _style(16, FontWeight.w400, 1.5, AppColors.textPrimary);
  static TextStyle get bodyM =>
      _style(14, FontWeight.w400, 1.5, AppColors.textPrimary);
  static TextStyle get label =>
      _style(14, FontWeight.w500, 1.4, AppColors.textPrimary);
  static TextStyle get caption =>
      _style(12, FontWeight.w400, 1.5, AppColors.textSecondary);

  static TextTheme get textTheme => TextTheme(
        displayLarge: display,
        headlineLarge: h1,
        headlineMedium: h2,
        titleLarge: h3,
        bodyLarge: bodyL,
        bodyMedium: bodyM,
        labelLarge: label,
        bodySmall: caption,
      );
}
