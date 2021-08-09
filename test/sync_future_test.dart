// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:useful_tools/event_queue.dart';

void main() async {
  test('sync Future', () async {
    Future<int> _sync() {
      final x = SynchronousFuture(1);
      print('_sync:${x.hashCode}');
      return x;
    }

    Future<int> _syncAsync() async {
      final x = SynchronousFuture(1);
      print('_syncAsync: ${x.hashCode}');
      return x;
    }

    void _syncAsyncTest() async {
      print('_test');
    }

    Future<void> _syncAsyncTestFuture() async {
      print('_test _syncAsyncTestFuture');
    }

    R Function(T) _re<R, T>(Zone zone, ZoneDelegate parenDelegate, Zone self,
        R Function(T) callback) {
      // print('re: $callback');
      return parenDelegate.registerUnaryCallback<R, T>(zone, callback);
    }

    await runZoned(() async {
      print('start...');

      /// [_Future._asyncComplete]
      ///
      /// 下面两个函数调用，返回的是[SynchronousFuture]
      /// 会经过[_Future._chainFuture]
      final x = _sync();
      print('..._sync:${x.hashCode}');
      final y = _syncAsync();

      /// [async] 修饰的函数会返回一个新[Future]对象
      print('..._syncAsync:${y.hashCode}');

      ///
      _syncAsyncTest();
      print('_syncAsync e');

      final tf = _syncAsyncTestFuture();
      print('_doe:');
      expect(x is SynchronousFuture<int>, true, reason: '${x.runtimeType}');
      expect(y is Future<int>, true);

      print('releaseUI');

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
            registerUnaryCallback: _re,
            createTimer: (zone, parent, self, duration, callback) {
              print('time....');
              return parent.createTimer(zone, duration, callback);
            }));
  });
}
