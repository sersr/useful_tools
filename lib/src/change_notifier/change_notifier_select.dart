import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

typedef ShouldNotify<D, T> = D Function(T notify);

class ChangeNotifierSelector<T, D> extends ChangeNotifier
    implements ValueListenable<D> {
  ChangeNotifierSelector({required this.parent, required this.notifyValue})
      : _value = notifyValue(parent.value);

  final ValueListenable<T> parent;
  final ShouldNotify<D, T> notifyValue;

  bool _add = false;
  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (!_add) {
      _add = true;
      parent.addListener(_listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _add = false;
      parent.removeListener(_listener);
    }
  }

  void _listener() {
    final value = notifyValue(parent.value);

    if (_value != value) {
      _value = value;
      notifyListeners();
    }
  }

  D _value;

  @override
  D get value => _value;
}
