import 'dart:async';

import 'package:flutter/material.dart';
import 'package:utils/utils.dart';

import 'export.dart';

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

  final tween = Tween<double>(begin: 0.0, end: 1.0);
  late final curve = tween.chain(CurveTween(curve: Curves.ease));
  double get tweenValue => controller.drive(curve).value;

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

  Widget build(BuildContext context);

  @protected
  void onCompleted() {}

  @protected
  void onDismissed() {}

  bool get active => _inited && !_closed;

  FutureOr<bool> showAsync() => show();
  bool show() {
    if (!active || !mounted) return false;
    _hided = false;
    controller.forward();
    return true;
  }

  bool get mounted => _overlayState?.mounted ?? false;

  bool _hided = false;
  bool get hided => _hided;

  bool hide() {
    if (!active || !mounted) return false;
    _hided = true;
    if (!shouldHide()) return false;

    if (controller.isDismissed) {
      onDismissed();
    } else if (controller.status != AnimationStatus.reverse) {
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

/// 异步
mixin OverlayDelegate {
  @protected
  Object get key;
  OverlayBase get overlayBase => Nav;

  FutureOr<OverlayState> getOverlay() {
    return overlayBase.getOverlay();
  }

  void init() {
    EventQueue.runOne(
        key, () => waitOverlay(initRun, overlayGetter: getOverlay));
  }

  Future<void> get future;
  bool get active;
  bool get done;

  @protected
  FutureOr<void> initRun(OverlayState overlayState) {}
}

class OverlayMixinDelegate with OverlayDelegate {
  OverlayMixinDelegate(this._controller, this.duration,
      {this.delayDuration = Duration.zero});
  @override
  Object get key => _controller;
  final OverlayMixin _controller;

  final Duration duration;
  final Duration delayDuration;

  bool _cancel = false;

  @override
  FutureOr<void> initRun(OverlayState overlayState) async {
    if (active) return;
    assert(overlayState.mounted);
    _controller.init(overlayState: overlayState, duration: duration);
    if (delayDuration != Duration.zero) {
      await release(delayDuration);
    }

    if (_cancel) {
      _controller.hide();
    } else {
      _controller.showAsync();
    }
    return future;
  }

  void show() {
    _cancel = false;
    if (done) _controller.showAsync();
  }

  @override
  Future<void> get future => _controller.future;
  @override
  bool get active => _controller.active;
  @override
  bool get done => _controller.inited;

  void hide() {
    _cancel = true;
    if (done) _controller.hide();
  }
}

/// deprecated
class OverlayMixinMultiDelegate with OverlayDelegate {
  OverlayMixinMultiDelegate(List<OverlayMixin> controllers, this.duration,
      {this.delayDuration = Duration.zero})
      : _controllers = List.of(controllers, growable: false);
  @override
  Object get key => _controllers;
  final List<OverlayMixin> _controllers;

  final Duration duration;
  final Duration delayDuration;

  bool _cancel = false;

  bool get mounted => _controllers.every((element) => element.mounted);

  @override
  FutureOr<void> initRun(OverlayState overlayState) async {
    if (active) return;
    assert(overlayState.mounted);
    for (var item in _controllers) {
      item.init(overlayState: overlayState, duration: duration);
    }
    if (delayDuration != Duration.zero) {
      await release(delayDuration);
    }
    // 如果没有调用一次`show`,`hide`不会触发状态监听
    _cancel ? forEach(_close) : forEach(_show);
    return future;
  }

  void show() {
    _cancel = false;
    if (done) forEach(_show);
  }

  @override
  Future<void> get future =>
      Future.wait(_controllers.map((element) => element.future));
  @override
  bool get active => _controllers.every((element) => element.active);
  @override
  bool get done => _controllers.every((element) => element.inited);

  void hide() {
    _cancel = true;
    if (done) {
      forEach(_hide);
    }
  }

  void _hide(OverlayMixin overlay) {
    overlay.hide();
  }

  void _show(OverlayMixin overlay) {
    overlay.showAsync();
  }

  void _close(OverlayMixin overlay) {
    overlay.close();
  }

  @pragma('vm:prefer-inline')
  void forEach(void Function(OverlayMixin overlay) action) {
    for (var item in _controllers) {
      action(item);
    }
  }
}
