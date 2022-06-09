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
  final _listenables = <ChangeNotifierAuto>{};

  void addListener(ChangeNotifierAuto listenable) {
    if (_listenables.contains(listenable)) return;
    assert(Log.i('${listenable.runtimeType} added'));
    _listenables.add(listenable);
    listenable.addListener(_listen);
  }

  void _listen() {
    if (mounted) setState(() {});
  }

  void removeListener(ChangeNotifierAuto listenable) {
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

extension ChangeAutoWrapExt<T> on ValueNotifier<T> {
  ChangeAutoWrapper<T> get al {
    return ChangeAutoWrapper(this);
  }
}

extension AutoListenNotifierExt<T> on T {
  AutoListenNotifier<T> get al {
    return AutoListenNotifier(this);
  }
}

mixin ChangeNotifierAuto on ChangeNotifier {
  void autoListen() {
    final state = Zone.current[_ChangeAutoState] as _ChangeAutoState?;
    if (state != null) {
      state.addListener(this);
    }
  }

  bool get disposed;
}

class AutoListenNotifier<T> extends ValueNotifier<T> with ChangeNotifierAuto {
  AutoListenNotifier(T value) : super(value);

  @override
  T get value {
    autoListen();
    return super.value;
  }

  bool _disposed = false;
  @override
  bool get disposed => _disposed;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class ChangeAutoWrapper<T> extends ChangeAutoWrapperBase<ValueNotifier<T>>
    implements ValueListenable<T> {
  ChangeAutoWrapper(ValueNotifier<T> parent) : super(parent);

  @override
  T get value {
    autoListen();
    return parent.value;
  }
}

class ChangeAutoWrapperBase<P extends ChangeNotifier> extends ChangeNotifier
    with EquatableMixin, ChangeNotifierAuto {
  ChangeAutoWrapperBase(this.parent);
  final P parent;

  @override
  void addListener(VoidCallback listener) {
    parent.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    parent.removeListener(listener);
  }

  @override
  bool get hasListeners {
    // ignore: invalid_use_of_protected_member
    return parent.hasListeners;
  }

  @override
  void notifyListeners() {
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    parent.notifyListeners();
  }

  bool _disposed = false;
  @override
  bool get disposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
    parent.dispose();
    super.dispose();
  }

  @override
  List<Object?> get props => [parent];
}
