import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import 'navigator_observer.dart';

mixin GetTypePointers {
  final _pointers = HashMap<Type, NopListener>();
  GetTypePointers? get parent;

  bool get isEmpty => _pointers.isEmpty;

  NopListener? getParentType<T>(BuildContext context, {bool shared = true}) =>
      parent?.getType<T>(context, shared: shared);

  NopListener? findParentType<T>(BuildContext context, {bool shared = true}) =>
      parent?.find(context, shared: shared);

  bool get isGlobal => false;

  NopListener getType<T>(BuildContext context, {bool shared = true}) {
    var listener = _pointers[T];
    if (listener == null && (shared || isGlobal)) {
      listener = getParentType<T>(context, shared: shared);
    }

    if (listener != null) {
      return listener;
    }
    final factory = Nav.get<T>();

    final data = factory.map(
      left: (left) => left(),
      right: (right) => right(context),
    );

    if (data is NopLifeCycle) data.init();

    return _pointers[T] = NopListener(data, () => _pointers.remove(T));
  }

  NopListener? find<T>(BuildContext context, {bool shared = true}) {
    var listener = _pointers[T];
    if (listener == null && (shared || isGlobal)) {
      listener = findParentType<T>(context, shared: shared);
    }

    return listener;
  }

  NopListener? getCurrentType<T>() {
    return _pointers[T];
  }

  bool isCurrent<T>() {
    if (isGlobal) {
      return parent?.isCurrent<T>() ?? false;
    }
    return _pointers.containsKey(T);
  }
}

mixin NopLifeCycle {
  void init();
  void dispose();

  static void autoDispse(Object lifeCycle) {
    if (lifeCycle is NopLifeCycle) {
      lifeCycle.dispose();
    } else if (lifeCycle is ChangeNotifier) {
      lifeCycle.dispose();
    } else {
      try {
        (lifeCycle as dynamic).dispose();
      } catch (_) {}
    }
  }
}

class NopListener {
  NopListener(this.data, this.onRemove);
  final dynamic data;
  final Set<Object> listener = {};

  final void Function() onRemove;

  bool _secheduled = false;

  void remove(Object key) {
    listener.remove(key);
    if (listener.isEmpty) {
      if (_secheduled) return;
      scheduleMicrotask(() {
        _secheduled = false;
        if (listener.isEmpty) {
          onRemove();
          NopLifeCycle.autoDispse(data);
        }
      });
      _secheduled = true;
    }
  }

  void add(Object key) {
    listener.add(key);
  }
}
