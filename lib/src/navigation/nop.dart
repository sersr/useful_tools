import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:nop/utils.dart';
import 'package:useful_tools/useful_tools.dart';

import 'dependences_mixin.dart';
import 'nop_pre_init.dart';
import 'typedef.dart';

extension GetType on BuildContext {
  /// [shared] 即使为 false, 也会在[Nop.page]中共享
  T getType<T>({bool shared = true}) {
    return Nop.of(this, shared: shared);
  }

  T? getTypeOr<T>({bool shared = true}) {
    return Nop.maybeOf(this, shared: shared);
  }
}

/// 当前共享对象的存储位置
/// page: 指定一个 虚拟 page,并不是所谓的页面，是一片区域；
/// 在一个页面中可以有多个区域，每个区域单独管理，由[shared]指定是否共享；
/// 在全局中有一个依赖链表，里面的对象都是共享的；
/// 在查找过程中，会在当前 page 依赖添加一个引用，即使是从其他 page 依赖获取的；
/// 不管在什么地方，查找都是从当前顶层 page 依赖查找(全局)，再从当前 page 查找或创建；
/// 如果没有 page，那么创建的对象只在特定的上下文共享
class Nop<C> extends StatefulWidget {
  const Nop({
    Key? key,
    required this.child,
    this.builder,
    @Deprecated('use initTypes or initTypesUnique instead') this.preRun,
    this.builders,
    this.create,
    this.initTypes = const [],
    this.initTypesUnique = const [],
  })  : value = null,
        isPage = false,
        super(key: key);

  const Nop.value({
    Key? key,
    this.value,
    required this.child,
    this.builder,
    @Deprecated('use initTypes or initTypesUnique instead') this.preRun,
    this.builders,
    this.initTypes = const [],
    this.initTypesUnique = const [],
  })  : create = null,
        isPage = false,
        super(key: key);

  /// page 共享域
  /// shared == false, 也会共享
  /// page 与 page 之间存在隔离
  ///
  /// 每个 page 都有一个 [NopDependences] 依赖节点
  /// [NopDependences] : 只保存引用，不添加监听，监听由[_NopState]管理
  /// page 释放会自动移除 依赖节点
  /// [NopListener] : 管理监听对象，当没有监听者时释放
  const Nop.page({
    Key? key,
    required this.child,
    this.builder,
    @Deprecated('use initTypes or initTypesUnique instead') this.preRun,
    this.builders,
    this.initTypes = const [],
    this.initTypesUnique = const [],
  })  : create = null,
        isPage = true,
        value = null,
        super(key: key);

  final Widget child;
  final NopPreInitCallback? preRun;
  final NopWidgetBuilder? builder;
  final List<NopWidgetBuilder>? builders;
  final C Function(BuildContext context)? create;
  final List<Type> initTypes;
  final List<Type> initTypesUnique;
  final C? value;
  final bool isPage;

  static bool print = false;

  static T of<T>(BuildContext context, {bool shared = true}) {
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScoop>()!;
    return nop.state.getType<T>(context, shared: shared);
  }

  static T? maybeOf<T>(BuildContext context, {bool shared = true}) {
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScoop>();
    return nop?.state.getType<T>(context, shared: shared);
  }

  static _NopState? _maybeOf(BuildContext context) {
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScoop>();
    return nop?.state;
  }

  /// 内部使用
  /// [t] 是 [T] 类型
  static T _ofType<T>(Type t, BuildContext context, {bool shared = true}) {
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScoop>()!;
    return nop.state.getTypeArg<T>(t, context, shared: shared);
  }

  @override
  State<Nop<C>> createState() => _NopState<C>();
}

class _NopState<C> extends State<Nop<C>> with NopListenerUpdate {
  final _caches = HashMap<Type, NopListener>();
  late final nopDependences = NopDependences();

  T getType<T>(BuildContext context, {bool shared = true}) {
    var listener = _getOrCreateCurrent(T);

    if (listener == null) {
      listener = getOrCreateDependence(T, context, shared: shared);
      _setListener(T, listener);
    }

    assert(!Nop.print || Log.i('get $T', position: 3));

    return listener.data;
  }

  T getTypeArg<T>(Type t, BuildContext context, {bool shared = true}) {
    var listener = _getOrCreateCurrent(t);

    if (listener == null) {
      listener = getOrCreateDependence(t, context, shared: shared);
      _setListener(t, listener);
    }

    assert(!Nop.print || Log.i('get $t returnType: $T', position: 3));

    return listener.data;
  }

  NopListener getOrCreateDependence(Type t, BuildContext context,
      {bool shared = true}) {
    final pageState = getPageNopState(this);
    final dependences = pageState?.nopDependences;

    NopListener? listener;

    if (shared) {
      // 当前页面查找
      listener = dependences?.findTypeArg(t, context);
      if (listener == null) {
        // 页面链表查找
        listener = currentDependences?.findTypeArg(t, context);
        // 全局查找
        listener ??= globalDependences.findTypeArg(t, context);

        if (listener != null) {
          /// 在当前 page 添加一个依赖
          dependences?.addListener(t, listener);
        }
      }
    } else {
      listener = pageState?._caches[t];
      assert(listener == null || pageState != this);
    }
    if (listener == null && pageState != null) {
      // 页面创建
      listener = dependences!.createListenerArg(t, context, shared: shared);
      // 如果不是共享那么在 page 添加一个监听引用
      if (!shared) {
        pageState._setListener(t, listener);
      }
    }

    assert(isPage ||
        nopDependences.parent == null && nopDependences.child == null);
    assert(pageState == null ||
        pageState.isPage &&
            pageState.nopDependences.lastChildOrSelf == currentDependences);

    return listener ?? createGlobalListener(t, context);
  }

  @pragma('vm:prefer-inline')
  static NopListener createGlobalListener(Type t, BuildContext context) {
    assert(Log.w('在全局创建 $t 对象', position: 5));

    return globalDependences.getTypeArg(t, context);
  }

  NopListener? _getOrCreateCurrent(Type t) {
    var listener = _caches[t];

    if (listener == null) {
      listener = _create(t);
      if (listener != null) {
        _setListener(t, listener);
      }
    }
    return listener;
  }

  NopListener? _create(Type t) {
    if (widget.create != null && t == C) {
      final data = widget.create!(context);
      if (data != null) {
        if (data is NopLifeCycle) data.init();
        return NopListener(data);
      }
    }
    return null;
  }

  static NopDependences? currentDependences;
  static final globalDependences = NopDependences();

  static void push(NopDependences dependences) {
    assert(currentDependences == null || currentDependences!.child == null);
    assert(dependences.parent == null && dependences.child == null);
    currentDependences?.insertChild(dependences);
    currentDependences = dependences;
  }

  static void pop(NopDependences dependences) {
    if (dependences == currentDependences) {
      assert(dependences.child == null);
      currentDependences = dependences.parent;
    }
    dependences.removeCurrent();
  }

  static _NopState? getPageNopState(_NopState currentState) {
    _NopState? state;
    if (currentState.isPage) {
      state = currentState;
    } else {
      final parentState = Nop._maybeOf(currentState.context);
      if (parentState != null) {
        state = getPageNopState(parentState);
      }
    }
    return state;
  }

  void _setListener(t, NopListener listener) {
    listener.add(this);
    _caches[t] = listener;
  }

  @override
  void update() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    isPage = widget.isPage;
    if (isPage) {
      push(nopDependences);
    }
    _initState();
  }

  bool isPage = false;
  void _initState() {
    if (widget.value != null) {
      final listener = NopListener(widget.value!);
      final data = listener.data;
      if (data is NopLifeCycle) {
        data.init();
      }
      _setListener(C, listener);
    }
  }

  @override
  void dispose() {
    _dispose();
    if (isPage) {
      pop(nopDependences);
    }
    super.dispose();
  }

  void _dispose() {
    for (var item in _caches.values) {
      item.remove(this);
    }
    _caches.clear();
  }

  @override
  Widget build(BuildContext context) {
    final child = NopPreInit(
      child: widget.child,
      preRun: widget.preRun,
      builder: widget.builder,
      builders: widget.builders,
      init: _init,
    );

    return _NopScoop(child: child, state: this);
  }

  static T _init<T>(Type t, context, {bool shared = true}) {
    return Nop._ofType<T>(t, context, shared: shared);
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
