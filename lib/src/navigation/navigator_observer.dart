import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:utils/utils.dart';

class NavObserver extends NavigatorObserver {
  bool get mounted => overlay?.mounted ?? false;

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

typedef _Callback<T> = FutureOr<T> Function();

typedef BoolOverlayStatus = bool Function();
typedef OverlayGetter = FutureOr<OverlayState> Function();

abstract class NavGlobal {
  final NavObserver observer = NavObserver();

  Future<OverlayState>? _future;
  Future<OverlayState> _getOverlay() {
    return _future ??= EventQueue.runTask(observer, () async {
      var count = 0;
      while (true) {
        final overlayState = observer.overlay;
        if (overlayState != null) {
          return overlayState;
        }

        assert(count++ == 0 || Log.e('count: $count'));
        final instance = SchedulerBinding.instance;
        if (instance == null) {
          await release(const Duration(milliseconds: 16));
        } else {
          await instance.endOfFrame;
        }
      }
    });
  }

  bool get _mouted => _overlayState?.mounted ?? false;

  OverlayState? _overlayState;
  FutureOr<OverlayState> get overlayState {
    _overlayState = observer.overlay;
    if (_overlayState == null || !_overlayState!.mounted) {
      if (_future != null) {
        return _future!.then((value) {
          if (value.mounted) return _overlayState = value;
          _future = null;
          return _default();
        });
      }
      return _default();
    }

    return _overlayState!;
  }

  Future<OverlayState> _default() {
    return _getOverlay().then((state) {
      if (_mouted) return _overlayState!;
      return _overlayState = state;
    });
  }

  FutureOr<OverlayState> getOverlay() {
    return overlayState;
  }

  bool overlayStatus() {
    return observer.navigator?.overlay?.mounted ?? false;
  }
}

class _NavGlobalImpl extends NavGlobal {}

// ignore: non_constant_identifier_names
final Nav = _NavGlobalImpl();
