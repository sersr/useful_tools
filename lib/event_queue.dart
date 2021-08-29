library event_queue;

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'common.dart';
import 'src/common/future_any.dart';

/// [_TaskEntry._run]
typedef EventCallback<T> = FutureOr<T> Function();
typedef EventRunCallback<T> = Future<void> Function(_TaskEntry<T> task);

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

  ///所有任务即时运行，[channels] 无限制
  EventQueue.run({this.channels = -1});
  final int channels;

  _ChannelState _getState() {
    if (channels < 1) {
      return _ChannelState.limited;
    } else if (channels > 1) {
      return _ChannelState.run;
    } else {
      return _ChannelState.one;
    }
  }

  // 运行任务
  Future<void> eventRun(_TaskEntry task) {
    return runZoned(task._run, zoneValues: {#zoneTask: task});
  }

  static _TaskEntry? get currentTask {
    final _t = Zone.current[#zoneTask];
    if (_t is _TaskEntry) return _t;
  }

  static final _queues = HashMap<ListKey, EventQueue>();
  static final iOQueue = createEventQueue('ioQueue');

  static EventQueue createEventQueue(key, {int channels = 1}) {
    List list;
    if (key is Iterable) {
      list = [...key, channels];
    } else {
      list = [key, channels];
    }
    final listKey = ListKey(list);

    return _queues.putIfAbsent(listKey, () => EventQueue(channels: channels));
  }

  static SchedulerBinding get scheduler => SchedulerBinding.instance!;

  final _taskPool = ListQueue<_TaskEntry>();

  bool get isLast => _taskPool.isEmpty;

  Future<void>? _runner;
  Future<void>? get runner => _runner;
  Future<T> _addEventTask<T>(EventCallback<T> callback,
      {bool onlyLastOne = false, Object? taskKey}) {
    final _task = _TaskEntry<T>(
      queue: this,
      taskKey: taskKey,
      callback: callback,
      onlyLastOne: onlyLastOne,
    );
    _taskPool.add(_task);
    final key = _task.taskKey;
    final future = _task.future;
    if (key != null) {
      final keyList = _keyEvents.putIfAbsent(key, () => <_TaskEntry>[]);
      if (keyList.isNotEmpty) {
        _task._setIgnore(keyList.first.ignore);
      }
      keyList.add(_task);
      future.whenComplete(() {
        keyList.remove(_task);
        if (keyList.isEmpty) {
          _keyEvents.remove(key);
        }
      });
    }
    run();
    return future;
  }

  /// 永远不要在单通道中(channels == 1)等待另一个任务
  /// 同样不要在任务中调用`await runner`
  ///
  /// ```dart
  /// final events = EventQueue();
  /// Future<void> _load() async {
  ///  // error: 任务永远不会完成
  ///  await events.addEventTask((){});
  ///  await events.runner;
  ///
  ///  // good
  ///  events.addEventTask((){});
  ///
  /// }
  ///
  /// events.addEventTask(_load);
  ///
  /// events.addEventTask(() async {
  ///   await ...
  ///   // 如果删除`await`，不会出错
  ///   _load();
  /// });
  /// ```
  Future<T> addEventTask<T>(EventCallback<T> callback, {Object? taskKey}) =>
      _addEventTask(callback, taskKey: taskKey);

  /// 如果该任务在队列中，并且不是最后一个，那么将被抛弃。
  /// 如果即将要运行的任务与队列中最后一个任务拥有相同的[taskKey]，那么也不会被抛弃，并且会即时
  /// 更改队列中同类型任务的状态，注意如果再次有任务插入并且[taskKey]与之不同，状态也会再次改变
  ///
  /// 无法抛弃正在运行中的任务。
  ///
  /// 返回的值可能为 null
  Future<T?> addOneEventTask<T>(EventCallback<T> callback, {Object? taskKey}) =>
      _addEventTask(callback, onlyLastOne: true, taskKey: taskKey);

  void run() async {
    _runner ??= _run()..whenComplete(() => _runner = null);
  }

  /// 自动选择要调用的函数
  late final EventRunCallback _runImpl = _getRunCallback();

  EventRunCallback _getRunCallback() {
    final _state = _getState();
    switch (_state) {
      case _ChannelState.limited:
        return _limited;
      case _ChannelState.run:
        return _runAll;
      default:
        return eventRun;
    }
  }

  /// 与[channels]关系密切
  final tasks = FutureAny();
  final _keyEvents = <Object, List<_TaskEntry>>{};
  Future<void> _limited(_TaskEntry task) async {
    tasks.add(eventRun(task));

    // 达到 channels 数              ||  最后一个
    while (tasks.length >= channels || _taskPool.isEmpty) {
      if (tasks.isEmpty) break;
      await tasks.any;
      await releaseUI;
    }
  }

  Future<void> _runAll(_TaskEntry task) async {
    tasks.add(eventRun(task));

    if (_taskPool.isEmpty) {
      while (tasks.isNotEmpty) {
        if (_taskPool.isNotEmpty) break;
        await tasks.any;
        await releaseUI;
      }
    }
  }

  @protected
  Future<void> _run() async {
    while (_taskPool.isNotEmpty) {
      await releaseUI;

      final task = _taskPool.removeFirst();
      //                      最后一个
      if (!task.onlyLastOne || _taskPool.isEmpty) {
        // 最后一个不管怎样都会执行
        assert(!task.ignore || _taskPool.isEmpty);

        await _runImpl(task);
      } else {
        final taskKey = task.taskKey;
        if (taskKey != null) {
          assert(_keyEvents.containsKey(taskKey));
          final taskList = _keyEvents[taskKey]!;

          // _taskPool.isNotEmpty
          final last = _taskPool.last;

          if (last.taskKey == task.taskKey) {
            if (taskList.first.ignore) {
              for (var t in taskList) {
                t._setIgnore(false);
              }
            }
            assert(!taskList.any((t) => t.ignore), '可能哪个地方错误了？');
          } else {
            if (!taskList.first.ignore) {
              for (var t in taskList) {
                t._setIgnore(true);
              }
            }
            assert(!taskList.any((t) => !t.ignore), '可能哪个地方错误了？');
          }
          await releaseUI;
        }
        if (!task.ignore) {
          await _runImpl(task);
          continue;
        }

        /// 任务被抛弃
        task.completed();
      }
    }

    assert(tasks.isEmpty);
  }
}

class _TaskEntry<T> {
  _TaskEntry({
    required this.callback,
    required EventQueue queue,
    this.taskKey,
    this.onlyLastOne = false,
  }) : _eventQueue = queue;

  /// 此任务所在的事件队列
  final EventQueue _eventQueue;

  /// 具体的任务回调
  final EventCallback<T> callback;

  /// 可通过[EventQueue.currentTask]访问、修改；
  /// 作为数据、状态等
  dynamic value;
  final Object? taskKey;

  /// [onlyLastOne] == true 并且不是任务队列的最后一个任务，才会被抛弃
  /// 不管 [onlyLastOne] 为任何值，最后一个任务都会执行
  final bool onlyLastOne;
  late bool _ignore = onlyLastOne;

  bool get ignore => _ignore;

  void _setIgnore(bool v) {
    if (onlyLastOne) {
      _ignore = v;
    }
  }

  final _completer = Completer<T>();

  Future<T> get future => _completer.future;

  // 队列循环要等待的对象
  Completer<void>? _innerCompleter;

  void _innerCompleted() {
    if (_innerCompleter != null) {
      assert(!_innerCompleter!.isCompleted);
      _innerCompleter!.complete();
      _innerCompleter = null;
    }
  }

  void _innerComplete(T result) {
    if (_innerCompleter != null) {
      _innerCompleted();
      completed(result);
    }
  }

  void _innerCompleteError(Object error) {
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
      result.then(_innerComplete, onError: _innerCompleteError);
      return _innerCompleter!.future;
    }
    // 同步
    completed(result);
  }

  /// 从 [EventQueue.currentTask] 访问
  void addLast() {
    assert(!_completed);
    assert(EventQueue.currentTask != null);

    _innerCompleted();
    scheduleMicrotask(() {
      if (_completed) return;
      _eventQueue._taskPool.add(this);
    });
  }

  bool _completed = false;

  /// [result] == null 的情况
  ///
  /// 1. [T] 为 void 类型
  /// 2. [onlyLastOne] == true 且被抛弃忽略
  void completed([T? result]) {
    if (_completed) return;

    _completed = true;
    // 应该让等待的代码块在下一次事件循环中执行
    Timer.run(() => _completer.complete(result));
  }

  void completedError(Object error) {
    if (_completed) return;

    _completed = true;
    _completer.completeError(error);
  }
}

enum _ChannelState {
  /// 任务数量无限制
  run,

  /// 数量限制
  limited,

  /// 单任务
  one,
}

/// 进入 事件循环，
Future<void> get releaseUI => Future(_empty);

// Future<void> get releaseUI => release(Duration.zero);
Future<void> release(Duration time) => Future.delayed(time);

void _empty() {}

extension EventsPush<T> on FutureOr<T> Function() {
  Future<T> pushWith({Object? eventKey, Object? taskKey}) {
    return EventQueue.createEventQueue(eventKey)
        .addEventTask(this, taskKey: taskKey);
  }

  Future<T?> pushOneWith({Object? eventKey, Object? taskKey}) {
    return EventQueue.createEventQueue(eventKey)
        .addOneEventTask(this, taskKey: taskKey);
  }

  Future<T> push(EventQueue events, {Object? taskKey}) {
    return events.addEventTask(this, taskKey: taskKey);
  }

  Future<T?> pushOne(EventQueue events, {Object? taskKey}) {
    return events.addOneEventTask(this, taskKey: taskKey);
  }
}
