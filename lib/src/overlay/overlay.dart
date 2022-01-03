import 'dart:async';

import 'package:flutter/material.dart';
import 'package:utils/utils.dart';

import '../navigation/export.dart';

class OverlayBase with StateBase<OverlayState> {
  OverlayBase({required this.getOverlayState});

  OverlayState? Function() getOverlayState;
  @override
  OverlayState? get currentState => getOverlayState();
}

typedef StateGetter<T> = FutureOr<T?> Function();

FutureOr<void> waitOverlay(FutureOr<void> Function(OverlayState) run,
    {StateGetter<OverlayState>? overlayGetter}) async {
  overlayGetter ??= Nav.getOverlay;
  return waitState(run, overlayGetter);
}

/// 在同一个代码块中读取值
/// 确保初始化时，`state.mounted == true`
///
/// 通过`throw`退出循环
FutureOr<void> waitState<T extends State>(
    FutureOr<void> Function(T) run, StateGetter<T> stateGetter) async {
  Timer? timer;
  assert(() {
    timer = Timer(const Duration(seconds: 10), () {
      final isNav = stateGetter == Nav.getOverlay;
      Log.e('获取`overlay`过长，${isNav ? '要调用Nav方法,务必将`observer`添加`Navigator`中' : ''
          '`overlayGetter`长时间无返回值'}');
    });

    return true;
  }());

  while (true) {
    try {
      final overlaystate = await stateGetter();
      if (overlaystate != null && overlaystate.mounted) {
        assert(() {
          timer?.cancel();
          return true;
        }());
        return run(overlaystate);
      }
    } on OverlayGetterError catch (e) {
      assert(Log.i(e));
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
