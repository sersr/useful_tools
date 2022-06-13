import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:nop/utils.dart';

import '../navigation/navigator_observer.dart';

/// [GetTypePointers] 本身不添加监听
mixin GetTypePointers {
  final _pointers = HashMap<Type, NopListener>();
  GetTypePointers? get parent;
  GetTypePointers? get child;

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
    var listener = _findTypeArgSet(t);
    listener ??= _createListenerArg(t, context, shared);
    return listener;
  }

  NopListener? _findTypeArgSet(Type t) {
    var listener = _findCurrentTypeArg(t);
    listener = _findTypeOtherElement(t);
    if (listener != null && !_pointers.containsKey(t)) {
      _pointers[t] = listener;
    }

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
    assert(!_pointers.containsKey(t));
    _pointers[t] = listener;
  }

  NopListener? findType<T>() {
    return _findTypeElement(getAlias(T));
  }

  bool contains(GetTypePointers other) {
    bool contains = false;
    visitElement((current) => contains = current == other);

    return contains;
  }

  void visitElement(bool Function(GetTypePointers current) visitor) {
    if (visitor(this)) return;
    visitOtherElement(visitor);
  }

  void visitOtherElement(bool Function(GetTypePointers current) visitor) {
    GetTypePointers? current = parent;
    var success = false;
    while (current != null) {
      if (success = visitor(current)) return;
      current = current.parent;
    }

    if (!success) {
      current = child;
      while (current != null) {
        if (visitor(current)) return;
        current = current.child;
      }
    }
  }

  NopListener? _findTypeElement(Type t) {
    NopListener? listener;

    visitElement(
        (current) => (listener = current._findCurrentTypeArg(t)) != null);

    return listener;
  }

  NopListener? findTypeArg(Type t) {
    return _findTypeElement(getAlias(t));
  }

  NopListener? findTypeArgOther(Type t) {
    return _findTypeOtherElement(getAlias(t));
  }

  NopListener? _findTypeOtherElement(Type t) {
    NopListener? listener;

    visitOtherElement((current) {
      assert(current != this);
      return (listener = current._findCurrentTypeArg(t)) != null;
    });

    return listener;
  }

  NopListener? _findCurrentTypeArg(Type t) {
    return _pointers[t];
  }

  NopListener? findCurrentTypeArg(Type t) {
    return _pointers[getAlias(t)];
  }

  static NopListener Function(dynamic data) nopListenerCreater = _defaultCreate;
  static NopListener _defaultCreate(dynamic data) => NopListenerDefault(data);

  static NopListener createArg(Type t, BuildContext context) {
    final factory = _get(t);

    final data = factory.map(
      left: (left) => left(),
      right: (right) => right(context),
    );

    if (data is NopLifeCycle) {
      try {
        data.init();
      } catch (e, s) {
        Log.e('$t init error: $e\n$s', onlyDebug: false);
      }
    }
    return nopListenerCreater(data);
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
}

typedef _Factory<T> = Either<BuildFactory<T>, BuildContextFactory<T>> Function(
    Type t);
mixin NopLifeCycle {
  void init();
  void nopDispose();

  static void autoDispse(Object lifeCycle) {
    assert(Log.w('dispose: ${lifeCycle.runtimeType}'));
    if (lifeCycle is NopLifeCycle) {
      lifeCycle.nopDispose();
    } else if (lifeCycle is ChangeNotifier) {
      lifeCycle.dispose();
    }
  }
}

mixin NopListenerUpdate {
  void update();
}

abstract class NopListener {
  NopListener(this.data);
  final dynamic data;
  bool get isEmpty;

  void remove(Object key);

  void add(Object key);
}

class NopListenerDefault extends NopListener {
  NopListenerDefault(dynamic data) : super(data);
  final Set<Object> _listener = {};

  @override
  bool get isEmpty => _listener.isEmpty;

  bool _secheduled = false;

  bool _dispose = false;

  @override
  void remove(Object key) {
    assert(!_dispose);
    assert(_listener.contains(key));
    _listener.remove(key);

    final local = data;
    if (local is Listenable && key is NopListenerUpdate) {
      local.removeListener(key.update);
    }

    if (isEmpty) {
      if (_secheduled) return;
      scheduleMicrotask(() {
        _secheduled = false;
        if (isEmpty) {
          _dispose = true;
          NopLifeCycle.autoDispse(data);
        }
      });
      _secheduled = true;
    }
  }

  @override
  void add(Object key) {
    assert(!_dispose);
    assert(!_listener.contains(key));

    _listener.add(key);
    final local = data;
    if (local is Listenable && key is NopListenerUpdate) {
      local.addListener(key.update);
    }
  }
}
