import 'package:flutter/material.dart';

import '../overlay/export.dart';
import 'state_getter.dart';

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

class NavigatorBase with StateBase<NavigatorState> {
  NavigatorBase(this.getNavigator);
  NavigatorState? Function() getNavigator;
  @override
  NavigatorState? get currentState => getNavigator();
}

abstract class NavInterface {}

class _NavGlobalImpl extends NavInterface {
  final NavObserver observer = NavObserver();
  late final _base = OverlayBase(getOverlayState: () => observer.overlay);
  late final _baseNav = NavigatorBase(() => observer.navigator);

  late final getOverlay = _base.getState;
  late final getNavigator = _baseNav.getState;
}

// ignore: non_constant_identifier_names
final Nav = _NavGlobalImpl();
