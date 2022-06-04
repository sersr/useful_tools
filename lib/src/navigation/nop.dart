import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:nop/nop.dart';

import 'dependences_mixin.dart';
import 'navigator_observer.dart';

typedef NopWidgetBuilder = Widget Function(BuildContext context, Widget child);
typedef NopPreInitCallback = void Function(
    T? Function<T>({bool shared}) preInit);

/// 当前共享对象的存储位置
class Nop extends StatefulWidget {
  const Nop({
    Key? key,
    required this.child,
    this.builder,
    this.preRun,
    this.builders,
  }) : super(key: key);

  final Widget child;
  final NopPreInitCallback? preRun;
  final NopWidgetBuilder? builder;
  final List<NopWidgetBuilder>? builders;

  static T of<T>(BuildContext context, {bool shared = true}) {
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScoop>()!;
    return nop.state.getType<T>(context, shared: shared);
  }

  static T? maybyOf<T>(BuildContext context, {bool shared = true}) {
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScoop>();
    return nop?.state.getType<T>(context, shared: shared);
  }

  @override
  State<Nop> createState() => _NopState();
}

class _NopState extends State<Nop> {
  final _caches = HashMap<Type, NopListener>();
  late final _getCacheStack = <Type, Set<String>>{};

  T getType<T>(BuildContext context, {bool shared = true}) {
    var listener = _caches[T];
    assert(() {
      final stack = _getCacheStack.putIfAbsent(T, () => <String>{});
      stack.add('shared: $shared > ' + Log.getLineFromStack(position: 4));
      return true;
    }());
    if (listener == null) {
      listener = Nav.getType<T>(context, shared: shared);

      listener.add(this);
      _caches[T] = listener;
    }
    assert(!shared && Nav.isCurrent<T>(), Log.e(_getCacheStack[T]));
    return listener.data;
  }

  @override
  void dispose() {
    for (var item in _caches.values) {
      item.remove(this);
    }
    _caches.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = NopPreInit(
      child: widget.child,
      preRun: widget.preRun,
      builder: widget.builder,
      builders: widget.builders,
    );

    return _NopScoop(child: child, state: this);
  }
}

/// 统一初始化对象
class NopPreInit extends StatefulWidget {
  const NopPreInit({
    Key? key,
    this.preRun,
    this.builder,
    this.builders,
    required this.child,
  }) : super(key: key);

  final NopPreInitCallback? preRun;
  final NopWidgetBuilder? builder;
  final List<NopWidgetBuilder>? builders;

  final Widget child;

  @override
  State<NopPreInit> createState() => _NopPreInitState();
}

class _NopPreInitState extends State<NopPreInit> {
  @override
  void initState() {
    if (widget.preRun != null) {
      widget.preRun!(_initFirst);
    }
    super.initState();
  }

  T _initFirst<T>({bool shared = true}) => Nop.of<T>(context, shared: shared);

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;
    if (widget.builder != null) {
      child = widget.builder!(context, child);
    }
    final builders = widget.builders;

    if (builders != null && builders.isNotEmpty) {
      for (var build in builders) {
        child = build(context, child);
      }
    }
    return child;
  }
}

class _NopScoop extends InheritedWidget {
  const _NopScoop({
    Key? key,
    required Widget child,
    required this.state,
  }) : super(key: key, child: child);
  final _NopState state;

  @override
  bool updateShouldNotify(covariant _NopScoop oldWidget) {
    return state != oldWidget.state;
  }
}
