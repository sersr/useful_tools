// import 'dart:collection';

// import 'package:flutter/material.dart';
// import 'package:nop/nop.dart';

// import 'dependences_mixin.dart';
// import 'navigator_observer.dart';
// import 'nop_pre_init.dart';
// import 'typedef.dart';

// extension GetNavType on BuildContext {
//   T getNavType<T>({bool shared = true}) {
//     return NopNav.of(this, shared: shared);
//   }

//   T? getNavTypeOr<T>({bool shared = true}) {
//     return NopNav.maybeOf(this, shared: shared);
//   }
// }

// /// 当前共享对象的存储位置
// class NopNav<C> extends StatefulWidget {
//   const NopNav({
//     Key? key,
//     required this.child,
//     this.builder,
//     this.preRun,
//     this.builders,
//     this.create,
//   })  : value = null,
//         super(key: key);
//   const NopNav.value({
//     Key? key,
//     this.value,
//     required this.child,
//     this.builder,
//     this.preRun,
//     this.builders,
//   })  : create = null,
//         super(key: key);

//   final Widget child;
//   final NopPreInitCallback? preRun;
//   final NopWidgetBuilder? builder;
//   final List<NopWidgetBuilder>? builders;
//   final C Function(BuildContext context)? create;
//   final C? value;

//   static T of<T>(BuildContext context, {bool shared = true}) {
//     final nop = context.dependOnInheritedWidgetOfExactType<_NopScoop>()!;
//     return nop.state.getType<T>(context, shared: shared);
//   }

//   static T? maybeOf<T>(BuildContext context, {bool shared = true}) {
//     final nop = context.dependOnInheritedWidgetOfExactType<_NopScoop>();
//     return nop?.state.getType<T>(context, shared: shared);
//   }

//   static _NopNavState? _maybeOf(BuildContext context) {
//     final nop = context.dependOnInheritedWidgetOfExactType<_NopScoop>();
//     return nop?.state;
//   }

//   @override
//   State<NopNav<C>> createState() => _NopNavState<C>();
// }

// class _NopNavState<C> extends State<NopNav<C>> {
//   final _caches = HashMap<Type, NopListener>();
//   late final _getCacheStack = <Type, Set<String>>{};

//   T getType<T>(BuildContext context, {bool shared = true}) {
//     var listener = _createOrFromParent<T>(context);

//     assert(() {
//       if (listener != null) {
//         final stack = _getCacheStack.putIfAbsent(T, () => <String>{});
//         stack.add('shared: $shared > ' + Log.getLineFromStack(position: 4));
//       }
//       return true;
//     }());

//     if (listener == null) {
//       listener = Nav.getType<T>(context, shared: shared);
//       _setListener<T>(listener);
//     }

//     assert(shared || Nav.isCurrent<T>(), Log.e(_getCacheStack[T]));
//     return listener.data;
//   }

//   NopListener? _createOrFromParent<T>(BuildContext context) {
//     var listener = _caches[T];

//     if (listener == null) {
//       listener = _create<T>();
//       if (listener == null) {
//         final parentState = NopNav._maybeOf(this.context);
//         if (parentState != null) {
//           listener = parentState._createOrFromParent<T>(context);
//         }
//       }
//       if (listener != null) {
//         _setListener<T>(listener);
//       }
//     }
//     return listener;
//   }

//   NopListener? _create<T>() {
//     if (widget.create != null && T == C) {
//       final data = widget.create!(context);
//       if (data != null) {
//         if (data is NopLifeCycle) data.init();
//         return NopListener(data);
//       }
//     }
//     return null;
//   }

//   @override
//   void initState() {
//     super.initState();
//     if (widget.value != null) {
//       final listener = NopListener(widget.value!);
//       final data = listener.data;
//       if (data is NopLifeCycle) {
//         data.init();
//       }
//       _setListener<C>(listener);
//     }
//   }

//   void _setListener<T>(NopListener listener) {
//     listener.add(this);
//     _caches[T] = listener;
//   }

//   void update() {
//     if (mounted) setState(() {});
//   }

//   @override
//   void dispose() {
//     for (var item in _caches.values) {
//       item.remove(this);
//     }
//     _caches.clear();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final child = NopPreInit(
//       child: widget.child,
//       preRun: widget.preRun,
//       builder: widget.builder,
//       builders: widget.builders,
//       init: _init,
//     );

//     return _NopScoop(child: child, state: this);
//   }

//   static T _init<T>(BuildContext context, {bool shared = true}) {
//     return NopNav.of(context, shared: shared);
//   }
// }

// class _NopScoop extends InheritedWidget {
//   const _NopScoop({
//     Key? key,
//     required Widget child,
//     required this.state,
//   }) : super(key: key, child: child);
//   final _NopNavState state;

//   @override
//   bool updateShouldNotify(covariant _NopScoop oldWidget) {
//     return state != oldWidget.state;
//   }
// }
