library event_queue;

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../common.dart';
import 'future_any.dart';

/// [_TaskEntry._run]
typedef EventCallback<T> = FutureOr<T> Function();

/// 以队列的形式进行并等待异步任务。
///
/// 目的：确保任务之间的安全性，或是减少资源占用
///
/// 如果一个异步任务被调用多次或多个异步任务访问相同的数据对象，
/// 那么在这个任务中所使用的的数据对象将变得不稳定
///
/// 异步任务不超过 [channels]
/// 如果 [channels] == 1, 那么任务之间所操作的数据是稳定的，除非任务不在队列中
///
/// 允许 [addOneEventTask], [addEventTask] 交叉使用
class EventQueue {
  EventQueue({this.channels = 1});
  EventQueue.none({this.channels = -1});

  static EventQueue? _instance;

  static EventQueue get instance {
    _instance ??= EventQueue();
    return _instance!;
  }

  static final iOQueue = EventQueue();

  final int channels;

  static SchedulerBinding get scheduler => SchedulerBinding.instance!;

  final _taskPool = ListQueue<_TaskEntry>();

  bool get isLast => _taskPool.isEmpty;

  Future<T> _addEventTask<T>(EventCallback<T> callback,
      {bool onlyLastOne = false}) {
    final _task = _TaskEntry<T>(callback, this, onlyLastOne: onlyLastOne
        // , objectKey: newKey
        );
    // final key = _task.key;

    // if (!_taskPool.containsKey(key)) {
    //   _taskPool[key] = _task;
    // } else {
    //   _task = _taskPool[key]! as _TaskEntry<T>;
    // }
    _taskPool.add(_task);
    assert(EventQueue.currentTask != _task, '如果想重新将当前任务安排进队列，');

    run();
    return _task.future;
  }

  /// 安排任务
  ///
  /// 队列模式
  ///
  /// 不被忽略
  Future<T> addEventTask<T>(EventCallback<T> callback, {Object? key}) =>
      _addEventTask<T>(callback);

  Future<dynamic> addSafeEventTask<T>(EventCallback<T> callback,
          {Object? key}) =>
      _addEventTask(callback);

  /// [onlyLastOne] 模式
  ///
  /// 如果该任务在队列中，并且不是最后一个，那么将被抛弃
  Future<T?> addOneEventTask<T>(EventCallback<T> callback, {Object? key}) =>
      _addEventTask<T?>(callback, onlyLastOne: true);

  Future<void>? _runner;
  Future<void>? get runner => _runner;

  void run() {
    _runner ??= _run()..whenComplete(() => _runner = null);
  }

  // @protected
  // Future<void> _run() async {
  //   /// 减少 [Future.wait] 带来的痛苦
  //   /// 避免重复 forEach
  //   final tasks = FutureAny();

  //   while (_taskPool.isNotEmpty) {
  //     await releaseUI;

  //     final task = _taskPool.values.first;

  //     assert(() {
  //       final keyFirst = _taskPool.keys.first;
  //       return keyFirst == task.key;
  //     }());

  //     // 最后一个
  //     final isEmpty = _taskPool.isEmpty;

  //     if (!task.onlyLastOne || isEmpty) {
  //       if (channels > 1) {
  //         tasks.add(eventRun(task));

  //         // 达到 channels 数           ||  最后一个
  //         if (tasks.length >= channels || isEmpty) {
  //           while (_taskPool.isEmpty || tasks.length >= channels) {
  //             if (tasks.isEmpty) break;
  //             await tasks.future;
  //             await releaseUI;
  //           }
  //         }
  //       } else {
  //         await eventRun(task);
  //       }
  //     } else {
  //       task.completed();
  //     }
  //     _taskPool.remove(task.key);
  //   }

  //   assert(tasks.isEmpty);
  // }
  late final _channelState = _channel();

  _ChannelState _channel() {
    if (channels < 1) {
      return _ChannelState.limits;
    } else if (channels > 1) {
      return _ChannelState.run;
    } else {
      return _ChannelState.one;
    }
  }

  /// 减少 forEach 次数
  final tasks = FutureAny();
  @protected
  Future<void> _run() async {
    while (_taskPool.isNotEmpty) {
      await releaseUI;

      final task = _taskPool.removeFirst();

      // 最后一个
      final isEmpty = _taskPool.isEmpty;

      if (!task.onlyLastOne || isEmpty) {
        final _runTask = eventRun(task);
        switch (_channelState) {
          case _ChannelState.limits:
            tasks.add(_runTask);

            // 达到 channels 数           ||  最后一个
            if (tasks.length >= channels || isEmpty) {
              while (_taskPool.isEmpty || tasks.length >= channels) {
                if (tasks.isEmpty) break;
                await tasks.future;
                await releaseUI;
              }
            }
            break;
          case _ChannelState.run:
            tasks.add(_runTask);
            if (isEmpty) {
              while (tasks.isNotEmpty) {
                if (_taskPool.isNotEmpty) break;
                await tasks.future;
                await releaseUI;
              }
            }
            break;
          default:
            await _runTask;
        }
      } else {
        task.completed();
      }
    }

    assert(tasks.isEmpty);
  }

  static const _zoneTask = 'eventTask';

  // 运行任务
  Future<void> eventRun(_TaskEntry task) {
    return runZoned(task._run, zoneValues: {_zoneTask: task});
  }

  static _TaskEntry? get currentTask {
    final _z = Zone.current[_zoneTask];
    if (_z is _TaskEntry) return _z;
  }
}

class _TaskEntry<T> {
  _TaskEntry(this.callback, this._looper, {this.onlyLastOne = false});

  final EventQueue _looper;
  final EventCallback<T> callback;

  dynamic value;

  final bool onlyLastOne;

  final _completer = Completer<T>();

  Future<T> get future => _completer.future;

  // 队列循环要等待的对象
  Completer<void>? _innerCompleter;

  int _count = 0;
  void _innerCompleted() {
    _count++;
    Log.i('count: $_count');
    if (_innerCompleter != null) {
      assert(!_innerCompleter!.isCompleted);
      _innerCompleter!.complete();
      _innerCompleter = null;
    }
  }

  void _complete(T result) {
    if (_innerCompleter != null) {
      _innerCompleted();
      completed(result);
    }
  }

  void _completeError(Object error) {
    if (_innerCompleter != null) {
      _innerCompleted();
      completedError(error);
    }
  }

  Future<void> _run() async {
    final result = callback();
    if (result is Future<T>) {
      assert(_innerCompleter == null);
      _innerCompleter ??= Completer<void>();
      result.then(_complete, onError: _completeError);
      return _innerCompleter!.future;
    }
    completed(result);
  }

  /// 从 [EventQueue.currentTask] 访问
  void addLast() {
    assert(!_completed);
    assert(EventQueue.currentTask != null);

    _innerCompleted();
    scheduleMicrotask(() {
      if (_completed) return;
      _looper._taskPool.addLast(this);
      _looper.run();
    });
  }

  bool _completed = false;

  void completed([T? result]) {
    if (_completed) return;

    _completed = true;

    _completer.complete(result);
  }

  void completedError(Object error) {
    if (_completed) return;

    _completed = true;
    _completer.completeError(error);
  }
}

enum _ChannelState {
  run,
  limits,
  one,
}

// class _TaskKey<T> {
//   _TaskKey(this._looper, this.callback, this.onlyLastOne, this.key);
//   final EventQueue _looper;
//   final EventCallback callback;
//   final bool onlyLastOne;
//   final Object? key;
//   @override
//   bool operator ==(Object other) {
//     return identical(this, other) ||
//         other is _TaskKey<T> &&
//             callback == other.callback &&
//             _looper == other._looper &&
//             onlyLastOne == other.onlyLastOne &&
//             key == other.key;
//   }

//   @override
//   int get hashCode => hashValues(callback, _looper, onlyLastOne, key);
// }

Future<void> get releaseUI => release(Duration.zero);
Future<void> release(Duration time) => Future.delayed(time);
