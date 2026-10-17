import 'dart:io';

/// The real OS, unlike `defaultTargetPlatform`, which is Android under `flutter test`.
bool get runsOnAndroid => Platform.isAndroid;
