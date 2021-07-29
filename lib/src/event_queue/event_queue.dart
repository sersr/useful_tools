library event_queue;

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

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

  static EventQueue? _instance;

  static EventQueue get instance {
    _instance ??= EventQueue();
    return _instance!;
  }

  static final iOQueue = EventQueue();

  final int channels;

  static SchedulerBinding get scheduler => SchedulerBinding.instance!;

  final _taskPool = <_TaskKey, _TaskEntry>{};

  bool get isLast => _taskPool.isEmpty;

  Future<T> _addEventTask<T>(EventCallback<T> callback,
      {bool onlyLastOne = false, Object? newKey}) {
    var _task = _TaskEntry<T>(callback, this,
        onlyLastOne: onlyLastOne, objectKey: newKey);
    final key = _task.key;

    if (!_taskPool.containsKey(key)) {
      _taskPool[key] = _task;
    } else {
      _task = _taskPool[key]! as _TaskEntry<T>;
    }

    run();
    return _task.future;
  }

  /// 安排任务
  ///
  /// 队列模式
  ///
  /// 不被忽略
  Future<T> addEventTask<T>(EventCallback<T> callback, {Object? key}) =>
      _addEventTask<T>(callback, newKey: key);

  /// [onlyLastOne] 模式
  ///
  /// 如果该任务在队列中，并且不是最后一个，那么将被抛弃
  Future<T?> addOneEventTask<T>(EventCallback<T> callback, {Object? key}) =>
      _addEventTask<T?>(callback, onlyLastOne: true, newKey: key);

  Future<void>? _runner;
  Future<void>? get runner => _runner;

  void run() {
    _runner ??= _run()..whenComplete(() => _runner = null);
  }

  @protected
  Future<void> _run() async {
    /// 减少 [Future.wait] 带来的痛苦
    /// 避免重复 forEach
    final tasks = FutureAny();

    while (_taskPool.isNotEmpty) {
      await releaseUI;

      final task = _taskPool.values.first;

      assert(() {
        final keyFirst = _taskPool.keys.first;
        return keyFirst == task.key;
      }());

      _taskPool.remove(task.key);

      // 最后一个
      final isEmpty = _taskPool.isEmpty;

      if (!task.onlyLastOne || isEmpty) {
        if (channels > 1) {
          tasks.add(eventRun(task));

          // 达到 channels 数           ||  最后一个
          if (tasks.length >= channels || isEmpty) {
            while (_taskPool.isEmpty || tasks.length >= channels) {
              assert(() {
                debugPrint('channels: ${tasks.length}');
                return true;
              }());
              if (tasks.isEmpty) break;
              await tasks.future;
              await releaseUI;
            }
          }
        } else {
          await eventRun(task);
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
  _TaskEntry(this.callback, this._looper,
      {this.onlyLastOne = false, this.objectKey});

  final EventQueue _looper;
  final EventCallback<T> callback;

  dynamic value;
  final Object? objectKey;
  final bool onlyLastOne;

  late final key = _TaskKey<T>(_looper, callback, onlyLastOne, objectKey);

  final _completer = Completer<T>();

  Future<T> get future => _completer.future;

  Future<void> _run() async {
    final result = await callback();
    completed(result);
  }

  bool loop = false;
  bool _completed = false;

  void completed([T? result]) {
    assert(!_completed);
    assert(_completed = true);

    assert(!_looper._taskPool.containsKey(key));

    if (loop) {
      _looper._taskPool[key] = this;
      assert(!(_completed = false));
      loop = false;
    } else {
      _completer.complete(result);
    }
  }
}

class _TaskKey<T> {
  _TaskKey(this._looper, this.callback, this.onlyLastOne, this.key);
  final EventQueue _looper;
  final EventCallback callback;
  final bool onlyLastOne;
  final Object? key;
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _TaskKey<T> &&
            callback == other.callback &&
            _looper == other._looper &&
            onlyLastOne == other.onlyLastOne &&
            key == other.key;
  }

  @override
  int get hashCode => hashValues(callback, _looper, onlyLastOne, key);
}

Future<void> get releaseUI => release(Duration.zero);
Future<void> release(Duration time) => Future.delayed(time);
