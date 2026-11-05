import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_controller.dart';
import 'router.dart';

class LibraryAccessApp extends ConsumerWidget {
  const LibraryAccessApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Library Access',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.current(),
      // Tokens switch instantly; an animated ThemeData lerp would lag behind.
      themeAnimationDuration: Duration.zero,
      locale: const Locale('vi', 'VN'),
      supportedLocales: const [Locale('vi', 'VN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
