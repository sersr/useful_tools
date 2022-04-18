import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:nop/event_queue.dart';
import 'package:nop/utils.dart';

Future<void> waitForFrame() {
  return SchedulerBinding.instance?.endOfFrame ??
      release(const Duration(milliseconds: 16));
}

/// 异步
mixin StateAsyncGetter<T extends State> {
  @protected
  Object get key;

  T? getState();

  Future<void> init() {
    return EventQueue.runOne(key, () => waitState(initRun, getState));
  }

  FutureOr<void> initRun(T state) {}
}
typedef StateGetter<T> = T? Function();

/// 在同一个代码块中读取值
/// 确保初始化时，`state.mounted == true`
///
/// 通过`throw`退出循环
FutureOr<void> waitState<T extends State>(
    FutureOr<void> Function(T) run, StateGetter<T> stateGetter) async {
  Timer? timer;
  assert(() {
    timer = Timer(const Duration(seconds: 10), () {
      Log.e('获取`overlay`过长`overlayGetter`长时间无返回值', position: 2);
    });

    return true;
  }());

  while (true) {
    try {
      final overlaystate = stateGetter();
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
