import 'dart:async';

import 'package:flutter/material.dart';
import 'package:utils/utils.dart';

import 'overlay_observer.dart';

/// 必须先调用[init]初始化
///
/// 提供动画基础
mixin OverlayMixin {
  OverlayState? _overlayState;

  OverlayState get overlay => _overlayState!;
  Future<void> get future => _completer.future;

  late final _completer = Completer<void>();
  void _complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  AnimationController get controller => _controller!;
  AnimationController? _controller;

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
      _controller?.dispose();
      _controller =
          AnimationController(vsync: overlayState, duration: duration);
      controller.addStatusListener(listenStatus);
      onCreateOverlayEntry();
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

  @protected
  void onCompleted() {
    _complete();
    onShowEnd?.call();
    _observer?.show(this);
  }

  @protected
  void onDismissed() {
    _complete();
    onHideEnd?.call();
    _observer?.hide(this);
  }

  VoidCallback? get onHideEnd => null;
  VoidCallback? get onShowEnd => null;

  OverlayObserver? _observer;

  void setObverser(OverlayObserver? observer) {
    if (observer != null) {
      observer.insert(this);
    }
    _observer = observer;
  }

  bool get active => _inited && !_closed;

  FutureOr<bool> showAsync() => show();
  bool show() {
    Log.w('status: ${controller.status}');
    if (!active || !mounted) return false;
    _hided = false;
    if (controller.isCompleted) {
      onCompleted();
    } else if (controller.status != AnimationStatus.forward ||
        !controller.isAnimating) {
      controller.forward();
    }
    return true;
  }

  bool get mounted => _overlayState?.mounted ?? false;

  bool _hided = true;
  bool get hided => _hided;

  FutureOr<bool> hideAsync() => hide();
  bool hide() {
    if (!active || !mounted) return false;
    _hided = true;
    if (!shouldHide()) return false;

    if (controller.isDismissed) {
      onDismissed();
    } else if (controller.status != AnimationStatus.reverse ||
        !controller.isAnimating) {
      controller.reverse();
    }
    return true;
  }

  bool shouldHide() => true;

  bool _closed = false;
  bool get closed => _closed;

  /// 如果被调用了，对象将不可用
  void close() {
    if (!active) return;
    _closed = true;
    _observer?.close(this);
    _complete();
    onRemoveOverlayEntry();
    _controller?.dispose();
    _controller = null;
  }

  @protected
  void onCreateOverlayEntry() {}
  @protected
  void onRemoveOverlayEntry() {}
}
