// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:useful_tools/common.dart';

import 'run_zone.dart';

void main() async {
  test('sync Future', () async {
    Future<int> _sync() {
      final x = SynchronousFuture(1);
      Log.i('_sync: ${x.hashCode}', showPath: false);

      return x;
    }

    Future<int> _syncAsync() async {
      final x = SynchronousFuture(1);
      Log.i('_syncAsync: ${x.hashCode}', showPath: false);
      return x;
    }

    void _syncAsyncTest() async {
      Log.i('_syncAsyncTest', showPath: false);
    }

    Future<void> _syncAsyncTestFuture() async {
      Log.i('_syncAsyncTestFuture', showPath: false);
    }

    /// 本次事件循环之后调用
    runZone(() async {
      Timer.run(() {
        Log.e('timer', showPath: false);
      });
    });
    printDash(label: '_sync');
    await runZone(_sync);
    printDash(label: '_sync no await');
    await runZone(() async {
      _sync();
    });

    printDash(label: '_syncAsync');
    await runZone(_syncAsync);

    printDash(label: '_syncAsyncTest');
    await runZone(_syncAsyncTest);

    printDash(label: '_syncAsyncTestFuture');
    await runZone(_syncAsyncTestFuture);
    printDash(label: '_syncAsyncTestFuture then');
    await runZone(() => _syncAsyncTestFuture()
        .then((value) => Log.i('_syncAsyncTestFuture then', showPath: false)));
    printDash(label: '_syncAsyncTestFuture await');
    await runZone(() async {
      Log.i('_syncAsyncTestFuture start', showPath: false);
      await _syncAsyncTestFuture();
      Log.i('_syncAsyncTestFuture await', showPath: false);
    });

    printDash(label: 'timer');

    /// 代码可以在微任务和消息循环中执行
    ///
    /// 由[Timer]注册的消息回调，会在下一次事件循环中执行
    ///
    /// 跟踪`createTimer`，可以看出调用[Timer.run]会注册消息回调，
    /// 但是任务的执行却在最后，上面的异步函数使用`await`修饰，也不是先执行消息回调，究其原因
    /// 还是因为上面的异步只是微任务异步，微任务中调用`scheduleMicrotask`,也还是在微任务中
    ///
    /// 从[Future]的factory函数可以看出，`Future`一般可以分为几类，消息异步，微任务异步和同步。
    ///
    /// `_Future`是[Future]的内部实现，位于`future_impl.dart`。
    /// [Future]任务完成后调用：
    /// `_asyncCompleteWithValue`: 会调用`scheduleMicrotask`，由微任务调用`_completeWithValue`
    /// `_completeWithValue`: 立即设置返回的值
    ///
    /// `await`: 对于此关键词，`future_impl.dart`有详细的说明。
    /// 与`then`的关系: `await`是由系统注册回调(将之后函数块内的代码包裹成一个回调函数)，
    /// 可以和同步一样编写代码，`then`需要手动注册回调，本质上是一个实例函数。
    ///
    /// 本实例中的异步只在微任务中，注册的消息回调也因为还未到达下一次事件循环而在消息队列中
    /// 如果要先执行[Timer.run]注册的消息回调，要插入消息异步，如：`await Future((){});`
    /// `Future((){})`内部调用[Timer],也就是说这是一个在等待的消息异步，后面的代码也只有在此异步
    /// 完成之后执行；这时进入到下一次事件循环，消息回调被执行，本次事件循环完成会立即调用微任务。
    ///
    /// 说明：如果一个[Future]在其内部中没有消息异步的可能，那它就只是微任务异步，恰好耗时严重，
    /// 那么在flutter中会出现卡顿的情况。为了解决这种情况可以在合适的地方插入消息异步：`await Future((){});`
    ///
    /// 在`flutter engine`中,由UI [TaskRunner] 处理 `message`,`microtask`和UI相关函数调用
    /// message：即事件任务，会调用`Dart_HandleMessage`处理一次dart的消息队列，
    /// 而在执行完本次任务之后会在向[TaskRunner]注册任务回调
    ///
    /// microtask: 微任务，`scheduleMicrotask`注册的任务由`engine`处理，
    /// 本来是在每一次的消息循环之后执行的
    ///
    /// 微任务和消息不同，它的实现是一个链表形式，(dart:async/schedule_microtask.dart)
    /// 一般来说`scheduleMicrotask`中的回调不该太复杂
    ///
    /// 在dart sdk 中(sdk/lib/_internal/vm/...)
    /// 从[Timer_patch.dart]可以看出，具体实现是[Timer_impl.dart]，
    /// 首先收集要处理的消息，在运行任务的过程中添加的消息并不会处理，而在已收集的消息执行完成之后，
    /// 会判断是否要给'唤醒线程'发送消息，'唤醒线程'不是直接与[Timer_impl.dart]直接交互，
    /// 上面提到的`Dart_HandleMessage`是处理消息的入口(对flutter engine runtime来说)，
    /// 也就是说在它们之间还有一个任务队列(TaskQueue)
    /// '唤醒线程'将需要的唤醒的任务发送到TaskQueue,由`Dart_HandleMessage`处理一次任务，
    /// runtime/vm/message_handler.cc, runtime/bin/event_handler.cc
    /// runtime/vm/port.cc: 由 portMap 管理 sendPort和与之相对应的消息处理函数
    ///
    /// 在 [TaskRunner] 中任务是有优先级的，会自动执行优先级高的任务
  });
}

void printDash({String label = ''}) {
  Log.e(label.padRight(30, '-'), showPath: false, zone: Zone.root);
}
