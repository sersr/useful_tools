// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:useful_tools/event_queue.dart';

void main() async {
  test('sync Future', () async {
    Future<int> _sync() {
      return SynchronousFuture(1);
    }

    Future<int> _syncAsync() async {
      return SynchronousFuture(1);
    }

    void _syncAsyncTest() async {
      print('_test');
    }

    Future<void> _syncAsyncTestFuture() async {
      print('_test _syncAsyncTestFuture');
    }

    R Function(T) _re<R, T>(Zone zone, ZoneDelegate parenDelegate, Zone self,
        R Function(T) callback) {
      print('re: $callback');
      return parenDelegate.registerUnaryCallback<R, T>(zone, callback);
    }

    await runZoned(() async {
      print('start...');
      final x = _sync();
      print('..._sync');
      final y = _syncAsync();
      print('..._syncAsync');
      _syncAsyncTest();
      final tf = _syncAsyncTestFuture();
      print('_doe');
      expect(x is SynchronousFuture<int>, true, reason: '${x.runtimeType}');
      expect(y is Future<int>, true);
      // print(t; static error: t: void

      /// 尽管[_syncAsyncTestFuture]函数中的语句是同步执行的(本次事件循环)，
      /// 但是本质上还是一个[Future],而当[Future]完成，会调用[scheduleMicrotask]设置返回值
      ///
      print('releaseUI');

      /// [_Future._addListener]
      ///
      /// 进入下次事件循环，[_Future]状态已改变，
      ///
      /// 注释此行，会有不一样的结果
      /// 由于参数[computation] 为 null,所以
      /// [Future.delayed] 是没有调用[scheduleMicrotask]的
      await releaseUI;

      tf.then((value) => print('done'));
      print(tf.runtimeType);
      await tf;
      print('await tf');
    },
        zoneSpecification: ZoneSpecification(
            scheduleMicrotask: (zone, parentDelegate, self, callback) {
              print(callback);
              parentDelegate.scheduleMicrotask(zone, callback);
            },
            registerUnaryCallback: _re));
  });
}
