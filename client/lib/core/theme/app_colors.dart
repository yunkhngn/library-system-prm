import 'package:flutter/material.dart';

/// Design tokens from Figma "Library Access — Design System" (01 Màu sắc),
/// plus a dark palette. Values follow [isDark]; switch it only through
/// `ThemeModeController`, which also rebuilds the widget tree.
abstract final class AppColors {
  static bool isDark = false;

  static Color _pick(int light, int dark) => Color(isDark ? dark : light);

  /// Brand accent; works both as a fill under white text and as a foreground.
  static Color get navy => _pick(0xFF173B63, 0xFF4F7FC0);
  static Color get action => _pick(0xFF2563EB, 0xFF4C8DF6);
  static Color get background => _pick(0xFFF5F7FA, 0xFF0B1220);
  static Color get surface => _pick(0xFFFFFFFF, 0xFF131C2B);
  static Color get textPrimary => _pick(0xFF182230, 0xFFE6EAF0);
  static Color get textSecondary => _pick(0xFF667085, 0xFF98A2B3);
  static Color get border => _pick(0xFFE4E7EC, 0xFF273244);
  static Color get success => _pick(0xFF15803D, 0xFF4ADE80);
  static Color get warning => _pick(0xFFB45309, 0xFFF5A524);
  static Color get error => _pick(0xFFB42318, 0xFFF97066);

  static Color get successSurface => _pick(0xFFECFDF3, 0xFF0F2A1C);
  static Color get warningSurface => _pick(0xFFFFF7ED, 0xFF2B1F0D);
  static Color get errorSurface => _pick(0xFFFEF3F2, 0xFF2E1515);
  static Color get infoSurface => _pick(0xFFEFF6FF, 0xFF13264A);
  static Color get neutralSurface => _pick(0xFFF2F4F7, 0xFF1C2638);

  static Color get sidebar => _pick(0xFF173B63, 0xFF0E1726);
  static Color get sidebarSelected => _pick(0xFF2C537A, 0xFF1F3554);
  static Color get sidebarMuted => _pick(0xFFB6C7DA, 0xFF8193AA);
}
