import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:nop/utils.dart';

import 'navigator_observer.dart';

/// [GetTypePointers] 本身不添加监听
mixin GetTypePointers {
  final _pointers = HashMap<Type, NopListener>();
  GetTypePointers? get parent;

  bool get isEmpty => _pointers.isEmpty;

  NopListener getType<T>(BuildContext context, {bool shared = true}) {
    return _getTypeArg(T, context, shared);
  }

  NopListener getTypeArg(Type t, BuildContext context, {bool shared = true}) {
    return _getTypeArg(t, context, shared);
  }

  /// shared == false, 不保存引用
  NopListener _getTypeArg(Type t, BuildContext context, bool shared) {
    t = getAlias(t);
    var listener = _findTypeArgSet(t, context, shared);
    listener ??= _createListenerArg(t, context, shared);
    return listener;
  }

  NopListener? _findTypeArgSet(Type t, BuildContext context, bool shared) {
    var listener = _pointers[t];
    if (listener == null && shared) {
      listener = _findParentTypeArg(t, context);
      if (listener != null) {
        _pointers[t] = listener;
      }
    }
    assert(listener == null ||
        shared ||
        Log.w('shared: $shared, listener != null,已使用 shared = true 创建过 $t 对象'));
    return listener;
  }

  NopListener createListenerArg(Type t, BuildContext context,
      {bool shared = true}) {
    t = getAlias(t);
    return _createListenerArg(t, context, shared);
  }

  NopListener _createListenerArg(Type t, BuildContext context, bool shared) {
    var listener = createArg(t, context);
    assert(!_pointers.containsKey(t));
    assert(Log.w('shared: $shared, create: $t'));
    if (shared) _pointers[t] = listener; // 只有共享才会添加到共享域中
    return listener;
  }

  void addListener(Type t, NopListener listener) {
    t = getAlias(t);
    _pointers[t] = listener;
  }

  static NopListener createArg(Type t, BuildContext context) {
    final factory = _get(t);

    final data = factory.map(
      left: (left) => left(),
      right: (right) => right(context),
    );

    if (data is NopLifeCycle) data.init();
    return NopListener(data);
  }

  static Type Function(Type t) getAlias = Nav.getAlias;

  static _Factory getFactory = Nav.getArg;

  static _Factory? _factory;

  static _Factory get _get {
    if (_factory != null) return _factory!;
    assert(Log.w('使用构建器，只初始化一次'));
    return _factory ??= getFactory;
  }

  static NopListener create<T>(BuildContext context) {
    return createArg(T, context);
  }

  NopListener? findType<T>(BuildContext context, {bool shared = true}) {
    return findTypeArg(T, context, shared: shared);
  }

  NopListener? findTypeArg(Type t, BuildContext context, {bool shared = true}) {
    t = getAlias(t);
    return shared ? _findArg(t, context) : _pointers[t];
  }

  /// 找到依赖时，在寻找过程中的所有节点都会添加一次引用
  NopListener? _findArg(Type t, BuildContext context) {
    return _pointers[t] ?? _findParentTypeArg(t, context);
  }

  NopListener? _findParentTypeArg(Type t, BuildContext context) =>
      parent?._findArg(t, context);
}

typedef _Factory<T> = Either<BuildFactory<T>, BuildContextFactory<T>> Function(
    Type t);
mixin NopLifeCycle {
  void init();
  void nopDispose();

  static void autoDispse(Object lifeCycle) {
    assert(Log.w('dispse: ${lifeCycle.runtimeType}'));
    if (lifeCycle is NopLifeCycle) {
      lifeCycle.nopDispose();
    } else if (lifeCycle is ChangeNotifier) {
      lifeCycle.dispose();
    } else {
      try {
        (lifeCycle as dynamic).nopDispose();
      } catch (_) {}
    }
  }
}

mixin NopListenerUpdate {
  void update();
}

class NopListener {
  NopListener(this.data);
  final dynamic data;
  final Set<Object> listener = {};

  bool _secheduled = false;

  void remove(Object key) {
    listener.remove(key);
    final local = data;
    if (local is Listenable) {
      if (key is NopListenerUpdate) local.removeListener(key.update);
    }
    if (listener.isEmpty) {
      if (_secheduled) return;
      scheduleMicrotask(() {
        _secheduled = false;
        if (listener.isEmpty) {
          NopLifeCycle.autoDispse(data);
        }
      });
      _secheduled = true;
    }
  }

  void add(Object key) {
    listener.add(key);
    final local = data;
    if (local is Listenable) {
      if (key is NopListenerUpdate) {
        local.addListener(key.update);
      }
    }
  }
}
