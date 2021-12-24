import 'dart:async';

import 'package:flutter/material.dart';
import 'package:utils/utils.dart';

import 'nav_overlay_mixin.dart';

class ToastController with OverlayMixin {
  ToastController({
    required this.content,
    required this.duration,
    this.bottomPadding = 80,
    this.color,
    this.radius,
    this.padding,
  });
  final Widget content;
  final double bottomPadding;
  final Duration duration;
  final Color? color;
  final BorderRadius? radius;
  final EdgeInsets? padding;
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomPadding,
      child: AnimatedBuilder(
        animation: _ignore,
        builder: (context, child) {
          return IgnorePointer(ignoring: _ignore.value, child: child);
        },
        child: SafeArea(
          child: GestureDetector(
            onTap: hide,
            child: FadeTransition(
              opacity: fadeAnimation,
              child: RepaintBoundary(
                child: Center(
                  child: IntrinsicWidth(
                    child: Material(
                      color: color,
                      borderRadius: radius,
                      child: Container(
                        padding: padding,
                        child: content,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  final _ignore = ValueNotifier(true);
  late final fadeAnimation = curve.animate(controller);
  @override
  void onCompleted() {
    if (hided) {
      close();
      return;
    } else {
      EventQueue.runOne(content, () => release(duration).whenComplete(hide));
    }
  }

  @override
  void onDismissed() {
    close();
  }

  @override
  void onShow() {
    EventQueue.push(ToastController, () {
      super.onShow();
      if (_ignore.value) {
        _ignore.value = false;
      }
      return future;
    });
  }

  @override
  void onHide() {
    super.onHide();
    if (!_ignore.value) {
      _ignore.value = true;
    }
  }
}

class ToastDelegate with OverlayDelegate {
  ToastDelegate(this._toastController, this.duration);

  final ToastController _toastController;
  final Duration duration;
  @override
  Object get key => _toastController;
  Future<void> get future => _toastController.future;
  @override
  FutureOr<void> initRun(OverlayState overlayState) async {
    assert(overlayState.mounted, '确保 `overlayState.mounted` == true');
    _toastController
      ..init(overlayState: overlayState, duration: duration)
      ..show();
  }

  bool get active => _toastController.active;

  void hide() {
    _toastController.hide();
  }
}
