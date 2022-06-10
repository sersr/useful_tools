import 'dart:async';

import 'package:flutter/foundation.dart';
import '../change_notifier/change_notifier_select.dart';

final _notifierMap = <Object, ValueNotifier<int>>{};

/// 记录与[key]关联的[ValueNotifier]
///
/// 当超出[saveCount]时，发送通知
///
/// note: [callback]返回的[Future]一定是可以完成的，如果是一个[Completer]的future，
/// 并且没有调用complete的话，记录的数值不会减少
Future<T> pushRecoder<T>(
    {required int saveCount,
    required Future<T> Function(ValueListenable<bool> pushNotifier) callback,
    required Object key}) {
  final notifier = _notifierMap.putIfAbsent(key, () => ValueNotifier(0));
  notifier.value += 1;
  final local = notifier.value;

  final notifierSelector =
      notifier.select((parent) => local < parent.value - saveCount);

  return callback(notifierSelector)
    ..whenComplete(() {
      notifier.value -= 1;
      if (notifier.value == 0) _notifierMap.remove(key);
    });
}
