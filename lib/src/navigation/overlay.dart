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
  FutureOr<OverlayState>? _future;

  FutureOr<OverlayState> getOverlay() => overlayState;

  FutureOr<OverlayState> get overlayState {
    _overlayState = overlay;
    if (_overlayState == null || !_overlayState!.mounted) {
      return _future.andThen((value) {
        if (value == null || !value.mounted) {
          _future = null;
          return _getDefault();
        }
        return _overlayState = value;
      });
    }

    return _overlayState!;
  }

  FutureOr<OverlayState> _getDefault() {
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
/// 确保初始化时，`overlaystate.mounted == true`
///
/// 通过`throw`退出循环
FutureOr<void> waitOverlay(FutureOr<void> Function(OverlayState) run,
    {OverlayGetter? overlayGetter}) async {
  overlayGetter ??= Nav.getOverlay;
  Timer? timer;
  assert(() {
    timer = Timer(const Duration(seconds: 10), () {
      final isNav = overlayGetter == Nav.getOverlay;
      Log.e(
          '获取`overlay`过长，${isNav ? '要调用Nav方法,务必将`observer`添加`Navigator`中' : ''
              '`overlayGetter`长时间无返回值'}',
          onlyDebug: false);
    });

    return true;
  }());

  while (true) {
    try {
      final overlaystate = await overlayGetter();
      if (overlaystate.mounted) {
        assert(() {
          timer?.cancel();
          return true;
        }());
        return run(overlaystate);
      }
    } on OverlayGetterError catch (e) {
      Log.i(e);
      break;
    } catch (e) {
      Log.e('unKnownError: $e');
      break;
    }

    await waitForFrame();
  }
  assert(() {
    timer?.cancel();
    return true;
  }());
}

/// 通过 `throw`,退出循环
class OverlayGetterError implements Exception {
  OverlayGetterError(this.message);

  final String message;

  @override
  String toString() {
    return 'OverlayGetterError: $message';
  }
}
