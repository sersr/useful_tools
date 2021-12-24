import 'dart:async';

import 'package:flutter/material.dart';
import 'package:utils/utils.dart';

import 'nav_overlay_mixin.dart';

class SnackBarController with OverlayMixin {
  SnackBarController({
    required this.stay,
    required this.content,
  });
  final Duration stay;
  final _privateKey = GlobalKey();
  final Widget content;

  bool _user = false;
  bool _userMode = false;
  bool _userHide = false;
  bool get canHide => _userHide || hided;

  void _userEnter(_) {
    _userMode = true;
    _user = true;
  }

  void _userleave([_]) {
    _userMode = false;
    if (value == 1.0) {
      _user = false;
    }
    if (canHide) hide();
  }

  void _userUpdate(DragUpdateDetails d) {
    if (closed) return;
    if (overlay.mounted) {
      try {
        final size = _privateKey.currentContext?.size;
        final offset = d.primaryDelta;
        if (size != null && offset != null) {
          value = value - offset / size.height;
          _userHide = value < 1.0;
        }
      } catch (e) {
        Log.e('error: $e');
      }
    }
  }

  @override
  bool shouldHide() => !_userMode;

  @override
  double get tweenValue => controller.drive(_user ? tween : curve).value;

  @override
  void onCompleted() {
    hided
        ? hide()
        : EventQueue.runOne(
            _privateKey, () => release(stay).whenComplete(hide));
  }

  @override
  void onDismissed() => close();

  @override
  void onShow() {
    EventQueue.push(SnackBarController, () {
      super.onShow();
      return future;
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Align(
          heightFactor: tweenValue,
          alignment: Alignment.topCenter,
          child: child,
        );
      },
      child: RepaintBoundary(
          key: _privateKey,
          child: Builder(builder: (context) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            final colorScheme = theme.colorScheme;
            final color = isDark
                ? colorScheme.onSurface
                : Color.alphaBlend(colorScheme.onSurface.withOpacity(0.80),
                    colorScheme.surface);
            return Material(
              color: color,
              child: DefaultTextStyle(
                // TODO: 需要统一管理
                style: TextStyle(
                    color: isDark
                        ? const Color.fromARGB(255, 44, 44, 44)
                        : const Color.fromARGB(255, 221, 221, 221)),
                child: SizedBox(width: double.infinity, child: content),
              ),
            );
          })),
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onVerticalDragStart: _userEnter,
        onVerticalDragUpdate: _userUpdate,
        onVerticalDragEnd: _userleave,
        onVerticalDragCancel: _userleave,
        child: child,
      ),
    );
  }
}

class SnackbarDelagate with OverlayDelagete {
  SnackbarDelagate(this._controller, this.duration,
      {this.delayDuration = Duration.zero});
  @override
  Object get key => _controller;
  final SnackBarController _controller;

  final Duration duration;
  final Duration delayDuration;

  bool _cancel = false;

  @override
  FutureOr<void> initRun(OverlayState overlayState) async {
    if (_controller.mounted) return;
    assert(overlayState.mounted);
    _controller.init(overlayState: overlayState, duration: duration);
    if (delayDuration != Duration.zero) {
      await release(delayDuration);
    }
    // 如果没有调用一次`show`,`hide`不会触发状态监听
    _cancel ? _controller.close() : _controller.show();
    return _controller.future;
  }

  Future<void> get future => _controller.future;

  void show() {
    _cancel = false;
    if (done) _controller.show();
  }

  bool get done => _controller.inited;
  void hide() {
    _cancel = true;
    if (done) _controller.hide();
  }
}
