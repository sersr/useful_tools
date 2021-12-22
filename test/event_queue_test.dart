import 'package:flutter_test/flutter_test.dart';
import 'package:utils/utils.dart';

/// 针对[EventQueue]的单元测试
void main() async {
  test('event tasks 01', () async {
    final events = EventQueue();
    final first = events.awaitTask(() => Log.i('first'));
    final second =
        events.awaitOne(() => Log.i('seconds'), taskKey: 'same');
    final mid =
        events.awaitOne(() => Log.i('seconds -- mid -- thrid'));
    final third =
        events.awaitOne(() => Log.i('third'), taskKey: 'same');
    await events.runner;
    expect(await first, true);
    expect(await second, true);
    expect(await mid, null); // 忽略的任务返回 null
    expect(await third, true);
  });

  test('event tasks 02', () async {
    final events = EventQueue();

    /// 由于在此代码块中都没机会进入下一次消息循环的机会
    /// [events]中的任务并没有真正的执行，所以才有验证的可能

    final first = events.awaitTask(() => Log.i('first'));
    final second =
        events.awaitOne(() => Log.i('seconds'), taskKey: 'same');
    final secMidThr =
        events.awaitOne(() => Log.i('seconds -- mid -- thrid'));

    final third =
        events.awaitOne(() => Log.i('third'), taskKey: 'same');

    final fourth = events.awaitOne(() => Log.i('fourth'));

    /// end
    await events.runner;
    expect(await first, true);
    expect(await second, null);
    expect(await secMidThr, null);
    expect(await third, null);
    expect(await fourth, true);
  });

  test('event tasks 03', () async {
    final events = EventQueue();

    await runZonePrint(() async {
      final first = events.awaitTask(() => Log.i('first'));
      final second =
          events.awaitOne(() => Log.i('seconds'), taskKey: 'same');
      final secMidThr =
          events.awaitOne(() => Log.i('seconds -- mid -- thrid'));

      final third =
          events.awaitOne(() => Log.i('third '), taskKey: 'same');

      expect(await first, true);
      expect(await second, true);

      /// 在[third]任务真正调用前，插入新任务，此时队列中最后一个任务发生改变
      /// 下次事件循环还未到来
      final fourth = events.awaitOne(() => Log.i('fourth'));
      Log.i('add fourth');
      expect(await secMidThr, null);
      expect(await third, null);
      expect(await fourth, true);

      await events.runner;
      (() => Log.i('hello')).push(events);
    });
  });
}
