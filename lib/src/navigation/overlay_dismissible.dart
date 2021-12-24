import 'dart:async';

import 'package:flutter/material.dart';
import 'package:utils/utils.dart';

import 'nav_overlay_mixin.dart';

mixin OverlayDismissible on OverlayMixin {
  Duration get stay;
  final _privateKey = GlobalKey();
  Widget get content;

  bool _user = false;
  bool _userMode = false;
  bool _userHide = false;
  bool get canHide => _userHide || hided;

  BorderRadius? radius;
  double? get positionLeft => 0;
  double? get positionRight => 0;
  double? get positionTop => 0;
  double? get positionBottom => 0;
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
        final localSize = size;
        final offset = d.primaryDelta;
        if (localSize != null && offset != null) {
          onUserUpdate(offset / localSize.height);
          _userHide = value < 1.0;
        }
      } catch (e) {
        Log.e('error: $e');
      }
    }
  }

  /// default: snackbar
  void onUserUpdate(double offset) {
    value = value - offset;
  }

  Size? get size {
    try {
      return _privateKey.currentContext?.size;
    } catch (e) {
      Log.i(e);
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
  Object get showKey => OverlayDismissible;
  @override
  void onShow() {
    EventQueue.push(showKey, () {
      super.onShow();
      return future;
    });
  }

  Widget buildChild(BuildContext context, Widget child);

  @override
  Widget build(BuildContext context) {
    final topNull = positionTop == null;
    final leftNull = positionLeft == null;
    final rightNull = positionRight == null;
    final bottomNull = positionBottom == null;
    final isTop = bottomNull && !topNull && !leftNull && !rightNull;
    // final isLeft = rightNull && !topNull && !leftNull && !bottomNull;
    // final isBottom = topNull && !leftNull && !rightNull && !bottomNull;
    // final isRight = leftNull && !topNull && !rightNull && !bottomNull;

    Widget child = RepaintBoundary(
        key: _privateKey,
        child: Builder(builder: (context) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          final colorScheme = theme.colorScheme;
          final color = isDark
              ? colorScheme.onSurface
              : Color.alphaBlend(
                  colorScheme.onSurface.withOpacity(0.80), colorScheme.surface);
          var padding = EdgeInsets.zero;
          if (isTop) {
            padding = padding.copyWith(top: positionTop);
            // } else if (isBottom) {
            //   padding = padding.copyWith(bottom: positionBottom);
            // } else if (isLeft) {
            //   padding = padding.copyWith(left: positionLeft);
            // } else if (isRight) {
            //   padding = padding.copyWith(right: positionRight);
          }
          return Padding(
            padding: padding,
            child: SafeArea(
              child: Material(
                color: color,
                borderRadius: radius,
                child: DefaultTextStyle(
                  // TODO: 需要统一管理
                  style: TextStyle(
                      color: isDark
                          ? const Color.fromARGB(255, 44, 44, 44)
                          : const Color.fromARGB(255, 221, 221, 221)),
                  child: SizedBox(width: double.infinity, child: content),
                ),
              ),
            ),
          );
        }));
    child = buildChild(context, child);

    return Positioned(
      top: isTop ? null : positionTop,
      left: positionLeft,
      right: positionRight,
      bottom: positionBottom,
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

class OverlayDismissibleDelegate with OverlayDelegate {
  OverlayDismissibleDelegate(this._controller, this.duration,
      {this.delayDuration = Duration.zero});
  @override
  Object get key => _controller;
  final OverlayDismissible _controller;

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
