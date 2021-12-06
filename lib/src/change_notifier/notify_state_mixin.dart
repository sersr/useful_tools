import 'package:flutter/foundation.dart';

mixin NotifyStateMixin {
  final _notifier = ValueNotifier(false);
  ValueListenable<bool> get stateNotifier => _notifier;

  void notifyState(bool open) => _notifier.value = open;
  void _addListener(VoidCallback callback) {
    _notifier.addListener(callback);
  }

  void _removeListener(VoidCallback callback) {
    _notifier.removeListener(callback);
  }
}

mixin NotifyStateOnChangeNotifier on ChangeNotifier {
  NotifyStateMixin? _handle;
  set handle(NotifyStateMixin? newHandle) {
    if (_handle != newHandle) {
      _handle?._removeListener(_listen);
      _handle = newHandle;
      if (_handle != null) {
        _handle?._addListener(_listen);
      }
    }
  }

  void _listen() {
    if (_handle == null) return;
    final open = _handle!._notifier.value;
    if (open) {
      onOpen();
    } else {
      onClose();
    }
  }

  @override
  void dispose() {
    handle = null;
    super.dispose();
  }

  void onOpen() {}
  void onClose() {}
}
