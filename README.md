
## useful tools

- binding: 其他widgets的依赖绑定，指针采样的修改方案
- change_notifier: 有选择的 `ValueNotifier`
- common: 常用的工具
- event_queue: 把相似的异步（Future）函数或会引起数据不稳定的函数添加到队列中，按顺序添加到`事件循环`中，或可抛弃`addOneEventTask`，或可增加进入`事件循环`的`channels`。
- image_ref_cache: 基于`File`的`imageCache`，不是继承关系；逐帧显示`Image`
- text_cache: 文本的异步布局和缓存，可以通过`key`找到`TextPainter`。为什么使用异步：不占用每一帧的UI时间，为长列表提供优化。
- wigdets: 部分是依赖包中基础创建的`Widget`

## 说一说

- 为什么使用异步UI还是会卡？

  dart是单线程，事件循环机制。 

  事件循环(伪代码)：
  ```dart
  final events = Queue<Event>();
  while(events.isNotEmpty) {
    final event = events.removeFirst();
    event.run();
    ...
  
  }

  class Event {
    void run() {
      ...
    // maybe
    events.add(asyncEvent);
    ...
    }
  }
  ```

  `事件`可以看做一个回调函数，`await`会通过系统注册回调。 
  异步有 Future, Stream。  
  本质上都是使用 `Timer` 和 `scheduleMicrotask`，在`sky_engine/lib/async/schedule_microtask.dart`中，微任务的实现一目了然，链表结构，不停迭代，可以发现，在迭代的过程中，依然可以在添加微任务，如果使用不当（注释示例）导致微任务循环队列无法停止，事件循环也就无法执行。通过`scheduleMicrotask`注册的回调应该是简洁，轻便的。

  如果一个函数本身就需要消耗不小的资源，使用Future并不会减少消耗，因为本质上是在同一个线程中执行，这时如果需要渲染就会在成卡顿；  
  解决方法：  
    - 使用`Isolate`，网络任务、数据库操作等一般都可以放在隔离中。  
    - 将函数转换成异步函数，在合适的地方插入`await Future.delayed(Duration.zero);`，dart就有空闲处理其他任务，如`drawFrame`。当然还能延伸出更有意思的用法，受事件循环启发的`event_queue`。

