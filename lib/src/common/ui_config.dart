import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../event_queue.dart';

Future<void> uiOverlay({bool hide = true}) {
  return EventQueue.runTaskOnQueue(uiOverlay, () {
    if (hide) {
      return SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      return SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  });
}

void uiStyle({bool dark = true}) {
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.white,
  ));
}

Future<void> setOrientation(bool portrait) {
  return EventQueue.runTaskOnQueue(setOrientation, () {
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
