import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';

typedef ShouldNotify<T, D extends ChangeNotifier> = T Function(D parent);

extension ValueNotifierSelector<D extends ChangeNotifier> on D {
  ChangeNotifierSelector<T, D> selector<T>(ShouldNotify<T, D> notifyValue) {
    return ChangeNotifierSelector(parent: this, notifyValue: notifyValue);
  }
}

class ChangeNotifierSelector<T, D extends ChangeNotifier> extends ChangeNotifier
    implements ValueListenable<T> {
  ChangeNotifierSelector({required this.parent, required this.notifyValue})
      : _value = notifyValue(parent);

  final D parent;
  final ShouldNotify<T, D> notifyValue;

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
    final value = notifyValue(parent);

    if (!const DeepCollectionEquality().equals(_value, value)) {
      _value = value;
      notifyListeners();
    }
  }

  T _value;

  @override
  T get value => _value;
}
