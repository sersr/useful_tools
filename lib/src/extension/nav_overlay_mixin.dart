import 'dart:async';

import 'package:flutter/material.dart';
import 'package:utils/utils.dart';

import '../navigation/navigator_observer.dart';

/// 必须先调用[init]初始化
mixin OverlayMixin {
  OverlayState? _overlayState;
  OverlayEntry? _entry;

  OverlayState get overlay => _overlayState!;
  OverlayEntry get entry => _entry!;
  Future<void> get future => _completer.future;

  late final _completer = Completer<void>();
  void _complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  final tween = Tween<double>(begin: 0.0, end: 1.0);
  late final curve = tween.chain(CurveTween(curve: Curves.ease));
  double get tweenValue => controller.drive(curve).value;

  late AnimationController controller;

  double get value => controller.value;
  set value(double v) {
    controller.value = v.clamp(0.0, 1.0);
  }

  bool get inited => _inited;

  bool _inited = false;
  void init({required OverlayState overlayState, required Duration duration}) {
    if (closed) return;
    if (!mounted) _inited = false;
    if (_inited) return;
    _overlayState = overlayState;
    if (mounted) {
      _inited = true;
      controller = AnimationController(vsync: overlayState, duration: duration);
      _entry = OverlayEntry(builder: build);
      overlay.insert(entry);
      controller.addStatusListener(listenStatus);
    } else {
      _overlayState = null;
      _entry?.remove();
    }
  }

  void listenStatus(AnimationStatus status) {
    if (closed) return;

    switch (controller.status) {
      case AnimationStatus.completed:
        onCompleted();
        break;
      case AnimationStatus.dismissed:
        onDismissed();
        break;
      default:
    }
  }

  Widget build(BuildContext context);

  @protected
  void onCompleted() {}

  @protected
  void onDismissed() {}

  bool get active => _inited && !_closed;

  void show() {
    if (!active) return;
    onShow();
  }

  void onShow() {
    if (!active) return;
    controller.forward();
  }

  bool get mounted => _overlayState?.mounted ?? false;

  bool _hided = false;
  bool get hided => _hided;

  void hide() {
    if (!active) return;
    _hided = true;
    if (shouldHide() && mounted) onHide();
  }

  void onHide() {
    if (!active) return;
    controller.reverse();
  }

  bool shouldHide() => true;

  bool _closed = false;
  bool get closed => _closed;

  /// 如果被调用了，对象将不可用
  void close() {
    if (!active) return;
    _closed = true;
    _complete();
    if (entry.mounted) {
      entry.remove();
    }
    controller.dispose();
    onClose();
  }

  @protected
  void onClose() {}
}

/// 异步
mixin OverlayDelagete {
  @protected
  Object get key;

  void init() {
    EventQueue.runOne(key, () => waitOverlay(initRun));
  }

  @protected
  FutureOr<void> initRun(OverlayState overlayState) {}
}
