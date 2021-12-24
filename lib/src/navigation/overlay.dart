import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:utils/utils.dart';

import 'navigator_observer.dart';

mixin OverlayBase {
  OverlayState? get overlay;
  bool overlayStatus() => overlay?.mounted ?? false;

  // cache
  OverlayState? _overlayState;
  Future<OverlayState>? _future;

  FutureOr<OverlayState> getOverlay() => overlayState;

  FutureOr<OverlayState> get overlayState {
    _overlayState = overlay;
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

  Future<OverlayState> _getDefault() {
    return _future ??= EventQueue.runTask(_getDefault, _default);
  }

  Future<OverlayState> _default() async {
    var count = 0;
    while (true) {
      final curerntOverlay = overlay;
      if (curerntOverlay != null && curerntOverlay.mounted) {
        return _overlayState = curerntOverlay;
      }
      assert(count++ == -1 || !debugMode || Log.w('count: $count'));
      await waitForFrame();
    }
  }
}

Future<void> waitForFrame() {
  return SchedulerBinding.instance?.endOfFrame ??
      release(const Duration(milliseconds: 16));
}

typedef OverlayGetter = FutureOr<OverlayState> Function();

/// 在同一个代码块中读取值
FutureOr<void> waitOverlay(FutureOr<void> Function(OverlayState) run,
    {OverlayGetter? overlayGetter}) async {
  overlayGetter ??= Nav.getOverlay;
  while (true) {
    final overlaystate = await overlayGetter();
    if (overlaystate.mounted) return run(overlaystate);

    await waitForFrame();
  }
}
