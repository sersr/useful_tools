import 'dart:async';

import 'package:flutter/material.dart';
import 'package:utils/utils.dart';

import 'nav_overlay_mixin.dart';
import 'navigator_observer.dart';
import 'overlay.dart';
import 'overlay_observer.dart';

/// 异步
mixin OverlayDelegate {
  @protected
  Object get key;
  OverlayBase get overlayBase => Nav;

  OverlayObserver? _overlayObserver;
  set overlay(OverlayObserver? overlayObserver) {
    _overlayObserver = overlayObserver;
  }

  FutureOr<OverlayState?> getOverlay() {
    final getter = _overlayObserver?.overlayGetter;
    if (getter != null) {
      return getter();
    }
    return overlayBase.getOverlay();
  }

  Future<void> init() {
    return EventQueue.runOne(
        key, () => waitOverlay(initRun, overlayGetter: getOverlay));
  }

  Future<void> get future;
  bool get active;
  bool get done;
  bool get hided;
  bool get closed;
  bool get isAnimating;
  bool get showing;
  bool get hiding;
  bool get showStatus;
  @protected
  FutureOr<void> initRun(OverlayState overlayState) {}
  FutureOr<bool> show();
  FutureOr<bool> hide();
  void toggle();
  void showToggle();
  void hideToggle();

  void close();
}

class OverlayMixinDelegate with OverlayDelegate {
  OverlayMixinDelegate(this._controller, this.duration,
      {this.delayDuration = Duration.zero});
  @override
  Object get key => _controller;
  final OverlayMixin _controller;

  final Duration duration;
  final Duration delayDuration;

  FutureOr<void>? get runner => EventQueue.getQueueRunner(key);

  @override
  Future<void> get future => _controller.future;
  @override
  bool get active => _controller.active;
  @override
  bool get done => _controller.inited;
  @override
  bool get hided => _controller.hided;
  @override
  bool get closed => _controller.closed;
  @override
  bool get isAnimating => done && _controller.isAnimating;
  @override
  bool get showing => done && _controller.showing;
  @override
  bool get hiding => done && _controller.hiding;
  @override
  bool get showStatus => done && _controller.showStatus;

  @override
  FutureOr<void> initRun(OverlayState overlayState) async {
    if (active) return;

    assert(overlayState.mounted);
    _controller.init(overlayState: overlayState, duration: duration);
    if (delayDuration != Duration.zero) {
      await release(delayDuration);
    }
    if (closed) return;

    _controller.setObverser(_overlayObserver);
  }

  @override
  Future<bool> show() async {
    if (closed) return false;
    if (done) return _controller.showAsync();
    return init().then((_) => _controller.showAsync());
  }

  @override
  Future<bool> hide() async {
    if (closed) return false;
    if (done) return _controller.hideAsync();
    return init().then((_) => _controller.hideAsync());
  }

  @override
  void toggle() {
    if (showStatus) {
      hide();
    } else {
      show();
    }
  }

  @override
  void showToggle() {
    if (showing) return;
    show();
  }

  @override
  void hideToggle() {
    if (hiding) return;
    hide();
  }

  @override
  void close() {
    _controller.close();
  }
}
