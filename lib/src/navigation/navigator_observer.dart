// ignore_for_file: unnecessary_overrides

import 'package:flutter/material.dart';

class NavObserver extends NavigatorObserver {
  OverlayState? get overlay => navigator?.overlay;

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
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

class NavigatorBase {
  NavigatorBase(this.getNavigator);
  NavigatorState? Function() getNavigator;

  NavigatorState? get currentState => getNavigator();
}

abstract class NavInterface {}

class _NavGlobalImpl extends NavInterface {
  final NavObserver observer = NavObserver();

  OverlayState? getOverlay() {
    return observer.overlay;
  }

  NavigatorState? getNavigator() {
    return observer.navigator;
  }
}

// ignore: non_constant_identifier_names
final Nav = _NavGlobalImpl();
