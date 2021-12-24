import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:utils/utils.dart';

import 'overlay.dart';

class NavObserver extends NavigatorObserver {
  OverlayState? get overlay => navigator?.overlay;

  @pragma('vm:prefer-inline')
  void _resetStatus() {}

  @override
  void didPop(Route route, Route? previousRoute) {
    _resetStatus();
    super.didPop(route, previousRoute);
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    _resetStatus();
    super.didPush(route, previousRoute);
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    _resetStatus();
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    _resetStatus();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  // @override
  // void didStartUserGesture(Route route, Route? previousRoute) {
  //   Log.w('didStartUserGesture', onlyDebug: false);

  //   super.didStartUserGesture(route, previousRoute);
  // }

  // @override
  // void didStopUserGesture() {
  //   Log.w('didStopUserGesture', onlyDebug: false);

  //   super.didStopUserGesture();
  // }
}

class _NavGlobalImpl with OverlayBase {
  final NavObserver observer = NavObserver();

  @override
  OverlayState? get overlay => observer.overlay;
}

// ignore: non_constant_identifier_names
final Nav = _NavGlobalImpl();
