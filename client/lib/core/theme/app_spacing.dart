import 'package:flutter/widgets.dart';

/// 8-point spacing grid.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class AppRadius {
  static const control = 8.0;
  static const card = 12.0;
  static const pill = 999.0;

  static const controlBorder = BorderRadius.all(Radius.circular(control));
  static const cardBorder = BorderRadius.all(Radius.circular(card));
}

/// Control heights per experience: desktop 40, mobile 48, kiosk 64.
abstract final class AppSizes {
  static const controlDesktop = 40.0;
  static const controlMobile = 48.0;
  static const controlKiosk = 64.0;

  static const sidebarWidth = 248.0;
  static const desktopBreakpoint = 1024.0;
  static const compactBreakpoint = 600.0;
}
