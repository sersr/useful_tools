import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nop/event_queue.dart';

Future<void> uiOverlay({bool hide = true}) {
  return EventQueue.run(uiOverlay, () {
    if (hide) {
      return SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      return SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  });
}

/// 用于初始化
///
/// note: 复杂场景使用[AnnotatedRegion],[SystemUiOverlayStyle]
void uiStyle({bool dark = false}) {
  SystemChrome.setSystemUIOverlayStyle(getOverlayStyle(dark: dark));
}

SystemUiOverlayStyle getOverlayStyle({bool dark = false, bool? statusDark}) {
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness:
        statusDark ?? dark ? Brightness.light : Brightness.dark,
    systemNavigationBarColor:
        dark ? const Color.fromARGB(255, 29, 29, 29) : Colors.white,
  );
}

Future<void> setOrientation(bool portrait) {
  return EventQueue.run(setOrientation, () {
    if (portrait) {
      return SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitDown,
        DeviceOrientation.portraitUp,
      ]);
    } else {
      return SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  });
}
