import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_colors.dart';

/// `true` = dark theme. The choice is persisted per device.
final themeModeProvider =
    NotifierProvider<ThemeModeController, bool>(ThemeModeController.new);

class ThemeModeController extends Notifier<bool> {
  static const _key = 'theme_mode';
  static const _storage = FlutterSecureStorage();

  /// Call before `runApp` so the first frame already uses the saved palette.
  static Future<void> restore() async {
    try {
      AppColors.isDark = await _storage.read(key: _key) == 'dark';
    } catch (_) {
      AppColors.isDark = false;
    }
  }

  @override
  bool build() => AppColors.isDark;

  void toggle() => setDark(!state);

  void setDark(bool dark) {
    if (dark == state) return;
    AppColors.isDark = dark;
    state = dark;
    // Tokens are plain getters, so const widgets would keep stale colors
    // unless every element is rebuilt.
    void markDirty(Element element) {
      element.markNeedsBuild();
      element.visitChildren(markDirty);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(markDirty);
    unawaited(_storage
        .write(key: _key, value: dark ? 'dark' : 'light')
        .catchError((Object _) {}));
  }
}
