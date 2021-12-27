import 'dart:async';

import 'package:utils/utils.dart';

import 'nav_overlay_mixin.dart';

mixin OverlayEvent on OverlayMixin {
  Completer<void>? _completer;

  void _complete() {
    if (_completer?.isCompleted == false) {
      _completer?.complete();
      _completer = null;
    }
  }

  Future<void> get fut {
    _completer ??= Completer();
    return _completer!.future;
  }

  @override
  void onCompleted() {
    super.onCompleted();
    _complete();
  }

  @override
  void onDismissed() {
    super.onDismissed();
    _complete();
  }

  @override
  FutureOr<bool> showAsync() {
    if (showing) return true;
    return super.showAsync().then((value) {
      if (showing) {
        return fut.then((_) => value);
      }
      return value;
    });
  }

  @override
  FutureOr<bool> hideAsync() {
    if (hiding) return true;
    return super.hideAsync().then((value) {
      if (hiding) {
        return fut.then((_) => value);
      }

      return value;
    });
  }
}
