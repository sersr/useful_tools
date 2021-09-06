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
  EventQueue.run() : channels = -1;
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

  static final iOQueue = EventQueue();

  static final _tempQueues = <Object, EventQueue>{};

  /// 确保拥有相同的[key]在同一个队列中
  static Future<T> runTaskOnQueue<T>(key, EventCallback<T> task,
      {int channels = 1}) {
    List list;
    if (key is Iterable) {
      list = [...key, channels];
    } else {
      list = [key, channels];
    }
    final listKey = ListKey(list);

    final _queue =
        _tempQueues.putIfAbsent(listKey, () => EventQueue(channels: channels));
    return _queue.awaitEventTask(task)
      ..whenComplete(() {
        if (_queue._taskPool.isEmpty) {
          _tempQueues.remove(listKey);
        }
      });
  }

  static Future<void>? getQueueRunner(key, {int channels = 1}) {
    List list;
    if (key is Iterable) {
      list = [...key, channels];
    } else {
      list = [key, channels];
    }
    final listKey = ListKey(list);
    return _tempQueues[listKey]?.runner;
  }

  static int checkTempQueueLength() {
    return _tempQueues.length;
  }

  static SchedulerBinding get scheduler => SchedulerBinding.instance!;

  final _taskPool = ListQueue<_TaskEntry>();

  bool get isLast => _taskPool.isEmpty;

  Future<void>? _runner;
  Future<void>? get runner => _runner;

  void run() async {
    _runner ??= _run()
      ..whenComplete(() {
        _runner = null;

        /// `完成`是微任务异步，存在任务池不为空的可能
        if (_taskPool.isNotEmpty) run();
      });
  }

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
      if (keyList.isEmpty) {
        _task.taskIgnore = _TaskIgnore(true);
      } else {
        assert(keyList.first.taskIgnore != null);
        _task.taskIgnore = keyList.first.taskIgnore;
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

  void addEventTask<T>(EventCallback<T> callback, {Object? taskKey}) =>
      _addEventTask(callback, taskKey: taskKey);

  /// 如果该任务在队列中，并且不是最后一个，那么将被抛弃。
  ///
  /// 例外:
  /// 如果即将要运行的任务与队列中最后一个任务拥有相同的[taskKey]，也不会被抛弃，并且会更改
  /// 状态，如果两个key相等(==)会共享一个状态([_TaskIgnore])，由共享状态决定是否被抛弃,
  /// 每次任务调用开始时，会自动检查与最后一个任务是否拥有相同的[taskKey]，并更新状态。
  ///
  /// 无法抛弃正在运行中的任务。
  ///
  /// 返回的值可能为 null
  void addOneEventTask<T>(EventCallback<T> callback, {Object? taskKey}) =>
      _addEventTask(callback, onlyLastOne: true, taskKey: taskKey);

  Future<T> awaitEventTask<T>(EventCallback<T> callback, {Object? taskKey}) {
    checkError();
    return _addEventTask(callback, taskKey: taskKey);
  }

  Future<T?> awaitOneEventTask<T>(EventCallback<T> callback,
      {Object? taskKey}) {
    checkError();
    return _addEventTask(callback, onlyLastOne: true, taskKey: taskKey);
  }

  void checkError() {
    assert(() {
      if (_state == _ChannelState.one &&
          EventQueue.currentTask?._eventQueue == this) {
        throw AwaitEventException(
          '在单通道(channels == 1)且在另一个任务(同一个队列)中，不应该使用`await`,'
          '可以考虑使用`addEventTask`或`addOneEventTask`',
        );
      }
      return true;
    }());
  }

  /// 自动选择要调用的函数
  late final EventRunCallback _runImpl = _getRunCallback();
  late final _ChannelState _state = _getState();
  EventRunCallback _getRunCallback() {
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

  /// 依赖于事件循环机制
  ///
  /// 每次循环都要进入一次事件循环等待，确保在循环中不会占用资源，flutter会自动判断要运行的任务
  /// 类别
  ///
  /// `flutter engine`中有一个`消息循环`遍历消息队列，UI相关的任务有较高的优先级，会先执行，
  /// dart 的消息循环在`flutter engine`中被定义为`microTask`，意为不是主要任务，
  /// 由`Dart_HandleMessage`实现，处理一次dart中的消息，完成之后会再次向`engine`的消息队列
  /// 注册一个新的任务实体，如此循环往复
  /// dart中的微任务定义为`observer`，微任务不是单独的任务实体，依附于当前运行的任务实体，而其
  /// 在dart中的实现是一个链表，并且是实时链接的，是在每次任务实体完成之后调用的，还是占用当前
  /// 任务实体的时间
  ///
  /// 异步(Future)相关：
  /// 类别：消息异步，微任务异步，同步
  /// 只有明确调用了[Timer]才是消息异步，才不会一直占用UI时间，把耗时的同步代码块转换为异步，
  /// 并在中间添加消息异步，如`await Future((){});`，这是一个没有延迟的消息异步，也就是说之
  /// 后的任务会在下次消息循环被调用，虽然完成时间比较久，但在每一帧中的耗时减少了，不会造成卡顿，
  /// 这样解决了不得不在主隔离中调用耗时函数的问题
  ///
  /// 微任务异步在任务实体完成之后调用并完成
  ///
  /// 同步：同步的[Future]对象，有时`异步`是[Future]，但是却不想`异步`，就可以同步的[Future]
  /// 冒充
  ///
  /// 可以自己实现[Future]，它只是一个类，所有的异步概念在`future_impl.dart`中实现，`异步完成`
  /// 是微任务实现的，所以在使用`await`时判断是否占用UI时间(vsync开始了，还未执行任务)，看异步
  /// 中是否包含消息异步代码就可以了，否则与同步无异，且本次任务实体未完成(UI 任务一直在队列中)；
  /// `ReceivePort`是通过dart的消息循环实现的，是消息异步，几乎所有的`通信`都是消息异步
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

          final last = _taskPool.last;

          final first = taskList.first;
          assert(first.taskIgnore != null);
          if (last.taskKey == task.taskKey) {
            first.ignore = false;
            assert(!taskList.any((t) => t.ignore), '可能哪个地方错误了？');
          } else {
            first.ignore = true;
            assert(!taskList.any((t) => !t.ignore), '可能哪个地方错误了？');
          }
        }

        /// 每次进入此处，会自动设置ignore，对于 onlyLastOne 没有关系，
        /// 相同的 key 共享同一对象，取得任一元素就可以完成操作，相对以往版本，减少for循环
        /// 带来的时间消耗(O(n))
        if (task.notIgnore) {
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

  bool get ignore => taskIgnore?.ignore == true;
  bool get notIgnore => taskIgnore?.ignore == false;

  set ignore(bool v) {
    taskIgnore?.ignore = v;
  }

  // 共享一个对象
  _TaskIgnore? taskIgnore;

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
    Timer.run(() {
      if (_completed) return;
      _eventQueue
        .._taskPool.add(this)
        ..run();
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

class _TaskIgnore {
  _TaskIgnore(this.ignore);

  bool ignore;
}

/// 进入 事件循环，
Future<void> get releaseUI => Future(_empty);

// Future<void> get releaseUI => release(Duration.zero);
Future<void> release(Duration time) => Future.delayed(time);

void _empty() {}

extension EventsPush<T> on FutureOr<T> Function() {
  void push(EventQueue events, {Object? taskKey}) {
    return events.addEventTask(this, taskKey: taskKey);
  }

  void pushOne(EventQueue events, {Object? taskKey}) {
    return events.addOneEventTask(this, taskKey: taskKey);
  }

  Future<T> pushAwait(EventQueue events, {Object? taskKey}) {
    return events.awaitEventTask(this, taskKey: taskKey);
  }

  Future<T?> pushOneAwait(EventQueue events, {Object? taskKey}) {
    return events.awaitOneEventTask(this, taskKey: taskKey);
  }
}

class AwaitEventException implements Exception {
  AwaitEventException(this.message);
  final String message;
  @override
  String toString() {
    return '${objectRuntimeType(this, 'AwaitEventException')}:  $message';
  }
}
