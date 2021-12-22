import 'package:flutter/material.dart';

class NavObserver extends NavigatorObserver {
  final _works = <void Function()>[];

  addWork(void Function() work) {
    _works.add(work);
  }

  void onResume() {
    if (_works.isNotEmpty) {
      final works = List.of(_works);
      _works.clear();
      for (var w in works) {
        w();
      }
    }
  }

  // @override
  // void didPop(Route route, Route? previousRoute) {
  //   Log.w('didPop', onlyDebug: false);
  //   super.didPop(route, previousRoute);
  // }

  @override
  void didPush(Route route, Route? previousRoute) {
    if (_works.isNotEmpty) {
      onResume();
    }
    // Log.w('didPush', onlyDebug: false);
    super.didPush(route, previousRoute);
  }

  // @override
  // void didRemove(Route route, Route? previousRoute) {
  //   Log.w('didRemove', onlyDebug: false);
  //   super.didRemove(route, previousRoute);
  // }

  // @override
  // void didReplace({Route? newRoute, Route? oldRoute}) {
  //   Log.w('didReplace', onlyDebug: false);

  //   super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  // }

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

abstract class NavGlobal {
  final NavObserver observer = NavObserver();
}

class _NavGlobalImpl extends NavGlobal {}

// ignore: non_constant_identifier_names
final Nav = _NavGlobalImpl();
