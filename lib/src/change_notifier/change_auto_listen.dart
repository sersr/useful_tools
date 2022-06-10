import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nop/utils.dart';

class ChangeAuto extends StatefulWidget {
  const ChangeAuto(this.builder, {Key? key}) : super(key: key);
  final Widget Function() builder;

  @override
  State<ChangeAuto> createState() => _ChangeAutoState();
}

class _ChangeAutoState extends State<ChangeAuto> {
  final _listenables = <AutoListenChangeNotifierMixin>{};

  void addListener(AutoListenChangeNotifierMixin listenable) {
    if (_listenables.contains(listenable)) return;
    assert(Log.i('${listenable.runtimeType} added'));
    _listenables.add(listenable);
    listenable.addListener(_listen);
  }

  void _listen() {
    if (mounted) setState(() {});
  }

  void removeListener(AutoListenChangeNotifierMixin listenable) {
    if (listenable.disposed) return;
    listenable.removeListener(_listen);
  }

  @override
  void dispose() {
    _listenables.forEach(removeListener);
    _listenables.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return runZoned(widget.builder, zoneValues: {_ChangeAutoState: this});
  }
}

extension ChangeAutoWrapExt<D, T extends ValueNotifier<D>> on T {
  AutoListenWrapper<D, T> get al {
    return AutoListenWrapper(this);
  }
}

extension ChangeAutoDelegateExt<D, T extends ValueListenable<D>> on T {
  AutoListenDelegate<D, T> get al {
    return AutoListenDelegate(this);
  }
}

extension AutoListenNotifierExt<T> on T {
  AutoListenNotifier<T> get al {
    return AutoListenNotifier(this);
  }
}

class AutoListenNotifier<T> extends ValueNotifier<T>
    with AutoListenChangeNotifierMixin {
  AutoListenNotifier(T value) : super(value);

  @override
  T get value {
    autoListen();
    return super.value;
  }

  @override
  void dispose() {
    autoDispose();
    super.dispose();
  }
}

class AutoListenWrapper<T, P extends ValueNotifier<T>>
    extends AutoListenDelegate<T, P> implements ValueNotifier<T> {
  AutoListenWrapper(P parent) : super(parent);

  @override
  set value(T newValue) {
    parent.value = newValue;
  }

  @override
  bool get hasListeners => parent.hasListeners;

  @override
  void notifyListeners() => parent.notifyListeners();

  @override
  void dispose() {
    parent.dispose();
    autoDispose();
  }
}

class AutoListenDelegate<T, P extends ValueListenable<T>>
    with
        AutoListenChangeNotifierMixin,
        AutoListenValueDelegateMixin<T, P>,
        AutoListenAddRemove<T, P>,
        EquatableMixin
    implements ValueListenable<T> {
  AutoListenDelegate(this.parent);

  @override
  final P parent;

  void updateParent(void Function(P parent) update) {
    update(parent);
  }

  @override
  List<Object?> get props => [parent];
}

mixin AutoListenChangeNotifierMixin implements Listenable {
  void autoListen() {
    final state = Zone.current[_ChangeAutoState] as _ChangeAutoState?;
    if (state != null) {
      state.addListener(this);
    }
  }

  bool _disposed = false;
  bool get disposed => _disposed;

  void autoDispose() {
    _disposed = true;
  }
}
mixin AutoListenValueDelegateMixin<T, P extends ValueListenable<T>>
    on AutoListenChangeNotifierMixin {
  P get parent;

  T get value {
    autoListen();
    return parent.value;
  }
}
mixin AutoListenAddRemove<T, P extends Listenable>
    on AutoListenChangeNotifierMixin {
  P get parent;

  @override
  void addListener(VoidCallback listener) {
    parent.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    parent.removeListener(listener);
  }
}
