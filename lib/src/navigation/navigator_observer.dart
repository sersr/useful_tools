import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:utils/utils.dart';

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

typedef BoolOverlayStatus = bool Function();
typedef OverlayGetter = FutureOr<OverlayState> Function();

abstract class NavGlobal {
  final NavObserver observer = NavObserver();

  OverlayState? _overlayState;
  FutureOr<OverlayState> getOverlay() => overlayState;

  FutureOr<OverlayState> get overlayState {
    _overlayState = observer.overlay;
    if (_overlayState == null || !_overlayState!.mounted) {
      return _future?.then((value) {
            if (value.mounted) return _overlayState = value;
            _future = null;
            return _getDefault();
          }) ??
          _getDefault();
    }

    return _overlayState!;
  }

  Future<OverlayState>? _future;

  Future<OverlayState> _getDefault() {
    return _future ??= EventQueue.runTask(observer, _default);
  }

  Future<OverlayState> _default() async {
    var count = 0;
    while (true) {
      final overlay = observer.overlay;
      if (overlay != null && overlay.mounted) {
        return _overlayState = overlay;
      }
      assert(count++ == -1 || !debugMode || Log.w('count: $count'));
      await waitForFrame();
    }
  }

  bool overlayStatus() => observer.overlay?.mounted ?? false;
}

Future<void> waitForFrame() {
  return SchedulerBinding.instance?.endOfFrame ??
      release(const Duration(milliseconds: 16));
}

FutureOr<void> waitOverlay(FutureOr<void> Function(OverlayState) run) async {
  while (true) {
    final overlaystate = await Nav.overlayState;
    if (overlaystate.mounted) return run(overlaystate);

    await waitForFrame();
  }
}

class _NavGlobalImpl extends NavGlobal {}

// ignore: non_constant_identifier_names
final Nav = _NavGlobalImpl();
