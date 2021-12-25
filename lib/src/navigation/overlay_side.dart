import 'dart:async';

import 'package:flutter/material.dart';
import 'package:utils/utils.dart';

import 'nav_overlay_mixin.dart';

mixin OverlaySide on OverlayMixin {
  Duration get stay;
  final _privateKey = GlobalKey();
  GlobalKey get privateKey => _privateKey;

  OverlayEntry? _entry;
  OverlayEntry get entry => _entry!;
  Widget get content;

  bool _user = false;
  bool _userMode = false;
  bool _userHide = false;
  bool get canHide => _userHide || hided;

  Color? get color => null;
  BorderRadius? get radius => null;
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
          final delta = offset / localSize.height;
          onUserUpdate(delta);
          _userHide = value < 1.0;
        }
      } catch (e) {
        Log.e('error: $e');
      }
    }
  }

  void onUserUpdate(double delta) {
    if (isTop || isLeft) {
      value = value + delta;
    } else if (isBottom || isRight) {
      value = value - delta;
    }
  }

  VoidCallback? get onTap => null;

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
    if (hided) return;
    EventQueue.runOne(_privateKey, () => release(stay).whenComplete(hide));
  }

  @override
  void onDismissed() => close();
  Object? get showKey => OverlaySide;

  @override
  FutureOr<bool> showAsync() {
    if (showKey == null) {
      return show().then((value) => future.then((_) => value));
    }
    return EventQueue.runTask(showKey, () {
      return show().then((value) => future.then((_) => value));
    });
  }

  @override
  @protected
  bool show() {
    return super.show();
  }

  @override
  void onCreateOverlayEntry() {
    _entry = OverlayEntry(builder: build);
    overlay.insert(entry);
  }

  @override
  void onRemoveOverlayEntry() {
    if (entry.mounted) {
      entry.remove();
    }
  }

  @mustCallSuper
  Widget buildChild(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final themeColor = isDark
        ? colorScheme.onSurface
        : Color.alphaBlend(
            colorScheme.onSurface.withOpacity(0.80), colorScheme.surface);
    var padding = EdgeInsets.zero;
    if (isTop) {
      padding = padding.copyWith(top: positionTop);
    }
    return Padding(
      key: _privateKey,
      padding: padding,
      child: SafeArea(
        child: Material(
          color: color ?? themeColor,
          borderRadius: radius,
          child: DefaultTextStyle(
            style: TextStyle(
                color: isDark
                    ? const Color.fromARGB(255, 44, 44, 44)
                    : const Color.fromARGB(255, 221, 221, 221)),
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      ),
    );
  }

  bool get topNull => positionTop == null;
  bool get leftNull => positionLeft == null;
  bool get rightNull => positionRight == null;
  bool get bottomNull => positionBottom == null;
  bool get isTop => bottomNull && !topNull && !leftNull && !rightNull;
  bool get isLeft => rightNull && !topNull && !leftNull && !bottomNull;
  bool get isBottom => topNull && !leftNull && !rightNull && !bottomNull;
  bool get isRight => leftNull && !topNull && !rightNull && !bottomNull;
  bool get isHorizontal => isLeft || isRight;
  bool get isVertical => isTop || isBottom;
  @override
  Widget build(BuildContext context) {
    Widget child = RepaintBoundary(
      child: Builder(
        builder: (context) {
          return buildChild(context, child: content);
        },
      ),
    );
    if (onTap != null) {
      child = GestureDetector(onTap: onTap, child: child);
    } else {
      child = GestureDetector(
        onHorizontalDragStart: isHorizontal ? _userEnter : null,
        onHorizontalDragUpdate: isHorizontal ? _userUpdate : null,
        onHorizontalDragEnd: isHorizontal ? _userleave : null,
        onHorizontalDragCancel: isHorizontal ? _userleave : null,
        onVerticalDragStart: isVertical ? _userEnter : null,
        onVerticalDragUpdate: isVertical ? _userUpdate : null,
        onVerticalDragEnd: isVertical ? _userleave : null,
        onVerticalDragCancel: isVertical ? _userleave : null,
        child: child,
      );
    }
    return Positioned(
      top: isTop ? null : positionTop,
      left: positionLeft,
      right: positionRight,
      bottom: positionBottom,
      child: child,
    );
  }
}
