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
  ///   // 在这种情况下，不会出错
  ///   _load();
  /// });
  /// ```
  Future<T> _addEventTask<T>(EventCallback<T> callback,
      {bool onlyLastOne = false}) {
    final _task = _TaskEntry<T>(
        callback: callback, queue: this, onlyLastOne: onlyLastOne);
    _taskPool.add(_task);
    run();
    return _task.future;
  }

  /// 安排任务 队列模式 不被忽略
  Future<T> addEventTask<T>(EventCallback<T> callback) =>
      _addEventTask(callback);

  // Future<dynamic> addSafeEventTask<T>(EventCallback<T> callback) =>
  //     _addEventTask(callback);

  /// [onlyLastOne] 模式
  ///
  /// 如果该任务在队列中，并且不是最后一个，那么将被抛弃。
  ///
  /// 无法抛弃正在运行中的任务。
  Future<T?> addOneEventTask<T>(EventCallback<T> callback) =>
      _addEventTask(callback, onlyLastOne: true);

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
        await _runImpl(task);
      } else {
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
    this.onlyLastOne = false,
  }) : _eventQueue = queue;

  /// 此任务所在的事件队列
  final EventQueue _eventQueue;

  /// 具体的任务回调
  final EventCallback<T> callback;

  /// 可通过[EventQueue.currentTask]访问、修改；
  /// 作为数据、状态等
  dynamic value;

  /// [onlyLastOne] == true 并且不是任务队列的最后一个任务，才会被抛弃
  /// 不管 [onlyLastOne] 为任何值，最后一个任务都会执行
  final bool onlyLastOne;

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

    _completer.complete(result);
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

// Future<void> get releaseUI => release(Duration.zero);
Future<void> get releaseUI => Future(_empty);

/// 进入 事件循环
Future<void> release(Duration time) => Future.delayed(time);

void _empty() {}
