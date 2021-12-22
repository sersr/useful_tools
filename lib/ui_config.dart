import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:utils/event_queue.dart';

Future<void> uiOverlay({bool hide = true}) {
  return EventQueue.runTask(uiOverlay, () {
    if (hide) {
      return SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      return SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  });
}

void uiStyle({bool dark = false}) {
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: Colors.white,
  ));
}

Future<void> setOrientation(bool portrait) {
  return EventQueue.runTask(setOrientation, () {
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
