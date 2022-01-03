import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:utils/utils.dart';

/// 异步获取`State`
///
mixin StateBase<T extends State> {
  T? getCurrentState() => null;

  T? get currentState => getCurrentState();
  bool stateStatus() => currentState?.mounted ?? false;

  // cache
  T? _state;
  FutureOr<T>? _future;

  FutureOr<T> getState() => state;

  FutureOr<T> get state {
    _state = currentState;
    if (_state == null || !_state!.mounted) {
      return _future.andMapOptionFut<T>(
        ifNone: _getDefault,
        ifSome: (state) {
          if (state.mounted) return _state = state;

          return _future = _getDefault();
        },
      );
    }

    return _state!;
  }

  FutureOr<T> _getDefault() {
    return EventQueue.run(_getDefault, _default);
  }

  Future<T> _default() async {
    var count = 0;
    while (true) {
      final localState = currentState;
      if (localState != null && localState.mounted) {
        return _state = localState;
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
